from enum import Enum
import time
import sys
import re

# "Jesteście sami w tej sali, odizolowani" ~ Kazimierz

input_paths = []
start_time = time.time()

romaddr = 0
ramaddr = 0
filesinclude = []
addralias = {}
labels = {}
code = []
memdata = []
instructions = {}
generated = {}
initinfo = {}
macros = {}
bssmap = {}
line = 0 
line_nr = 0
filen = ''
error_cnt = 0
oformat = 0
memmap = 0
elfexec = {}
bssaddr = 0
bssoff = 0
bssfin = 0

def compileAll():
    global romaddr, ramaddr
    parseArgs()
    initInstructions()

    for ip in input_paths:
        compileFileFirstRun(ip)
    
    romaddr = 0
    ramaddr = 0

    for ip in input_paths:
        compileFileSecondRun(ip)

    printv("DONE")
    printv(generated)
    printv("Writing files")
    if memmap:
        mmf = open(output_path + ".mm", "wt")
        for label in labels:
            mmf.write(""+label+" "+str(labels[label])+"\n")
        mmf.write("-p\n")
        for label in addralias:
            mmf.write(""+label+" "+str(addralias[label])+"\n")
        for label in bssmap:
            mmf.write(""+label+" "+str(bssmap[label]+bssoff)+"\n")
        mmf.close()
    
    output_file = open(output_path, "wb" if elfexec else "wt")

    if error_cnt == 0:
        cs=0
        if elfexec:
            layout_ram = 0
            if layout_ram:
                printv("ElfWrite: Selected RAM optimal profile (page aligned file)")
                dataoff = 0+0x34+0x20*2
                dataoff = (floor(dataoff/0x1000)+1)*0x1000

                output_file.write(make_elf_header())
                # LOAD prog section
                output_file.write(
                    make_elf_program_header(1, dataoff, 0, 0, romaddr*4, romaddr*4, 4+1))

                memoff = (floor((dataoff+(romaddr*4))/0x1000)+1)*0x1000
                # LOAD mem section
                output_file.write(
                    make_elf_program_header(1, memoff, 0, 0, bssoff*2, (bssoff+bssfin)*2, 4+2))
            else: # layout file 
                align = 1 # if we are only using 2 sections, align can be disabled (set to 1). Otherwise set to 0x1000. (mmap/copy)
                printv("ElfWrite: Selected FILE size optimal profile (memory wasted at start of pages due to file align)")
                dataoff = 0+0x34+0x20*2
                output_file.write(make_elf_header(dataoff))
       
                # LOAD prog section
                output_file.write(
                    make_elf_program_header(1, dataoff, dataoff%align, dataoff%align, romaddr*4, romaddr*4, 4+1, align))

                memoff = dataoff+(romaddr*4)
                # LOAD mem section
                output_file.write(
                    make_elf_program_header(1, memoff, memoff%align, memoff%align, bssoff*2, (bssoff+bssfin)*2, 4+2, align))
            # 3rd. file with disabled align?

            printv(f'Writing rom page from offset {dataoff} (size={romaddr})')
            output_file.seek(dataoff)
            for addr in range(romaddr):
                output_file.write(generated[addr].to_bytes(4, 'little'))
            
            printv(f'Writing ram page from offset {memoff} (size={bssoff})')
            output_file.seek(memoff)
            for addr in range(bssoff):
                output_file.write(initinfo[addr].to_bytes(2, 'little'))

        elif(oformat == 0):
            for addro, val in generated.items():
                addr = hex(addro)[2:].zfill(4)
                data = hex(val)[2:].zfill(8)
                cs+=val&0xFFFF
                cs+=(val>>16)
                cs=cs%65536
                hexentry = f':04{addr}00{data}'
                check = 0
                for i in range(0, len(hexentry[1:])-1, 2):
                    check = check + int(hexentry[i+1:i+3], 16)
                check = check % 256
                check = 256 - check
                hexentry = hexentry + (hex(check)[2:][-2:]).zfill(2) + '\n'
                hexentry = hexentry.upper()
                printv(hexentry[:-1])
                output_file.write(hexentry)
            output_file.write(':00000001FF\n')
        else:
            output_file.write('*')
            for addro, val in generated.items():
                data = hex(val)[2:].zfill(8)
                output_file.write(data)
                cs+=val&0xFFFF
                cs+=(val>>16)
                cs=cs%65536
            output_file.write(hex((65536-cs)%65536)[2:].zfill(8))
            output_file.write('*')
            if len(initinfo) > 0:
                lastinitaddr = bssoff-1 if elfexec else max(initinfo)
                for addr in range(0x4c00, lastinitaddr+1):
                    if addr in initinfo:
                        output_file.write(hex(initinfo[addr])[2:].zfill(4))
                    else:
                        output_file.write("0000")
            output_file.write('*')
        output_file.close()
    
    if error_cnt == 0:
        print('\033[0;32m[RESULT]\033[m Compilation finished successfully!')
        exitcode = 0
    else:
        print(f'\033[0;31m[RESULT]\033[m Compilation failed. {error_cnt} {"errors were" if error_cnt > 1 else "error was"} found!')
        exitcode = 1
    print(f'[INFO] Compilation time: {"%.5f" % float(time.time() - start_time)} seconds')

    return exitcode

def compileFileFirstRun(input_path):
    global romaddr, ramaddr, addralias, labels, macros, bssmap, bssoff, bssfin, bssaddr
    global filen, line, line_nr
    filen = input_path
    printv(f"Resolving addresses (compile 1st run) in {input_path}")
    input_file = open(input_path, "rt")

    seg = segment.ROMD

    for line_nr, line in enumerate(input_file, 1):
        line = prepare_line(line)
        ltype = get_line_type(line)

        printv(f'Linetype of {line_nr} is {ltype}')
        tokens = tokenize(line)

        if(ltype == linetype.PARAM):
            if(line.find('.romd') != -1):
                seg = segment.ROMD
            elif(line.find('.ramd') != -1):
                seg = segment.RAMD
            elif(line.find('.org') != -1):
                org = get_number(tokens[1])
                if(seg == segment.ROMD):
                    if(romaddr > org):
                        printe(f'Current rom address ({romaddr}) is higher then .org address ({org})')
                    else:
                        romaddr = org
                else:
                    if(ramaddr > org):
                        printe(f'Current ram address ({ramaddr}) is higher then .org address ({org})')
                    else:
                        ramaddr = org
            elif(line.find('.include') != -1):
                if tokens[1] in filesinclude:
                    printe(f'Include loop deteced. Skipping include {tokens[1]}')
                else:
                    compileFileFirstRun(tokens[1])
            elif(line.find('.global') != -1):
                if len(tokens) != 3:
                    printe('Expected 2 arguments')
                elif(tokens[1] in addralias):
                    printe(f'Label redeclaration "{tokens[1]}"')
                elif not elfexec:
                    printv(f'Global {tokens[1]} address is {ramaddr}')
                    addralias[tokens[1]] = ramaddr
                    if(seg == segment.ROMD):
                        printe('Global declaration in ROM section')
                    else:
                        ramaddr = ramaddr + get_number(tokens[2])
                else:
                    printv(f'ELFBSS: Global {tokens[1]} local address is {bssaddr}')
                    if(seg == segment.ROMD):
                        printe('Global dleclaration in ROM section')
                    elif(tokens[1] in bssmap):
                        printe(f'Label redeclaration "{tokens[1]}"')
                    else:
                        bssmap[tokens[1]] = bssaddr
                        bssaddr += get_number(tokens[2])

            elif(line.find('.rod') != -1): # use only if no OS - requires access to mem mapping to connect pmem to ram
                if len(tokens) < 2:
                    printe("Excepted > 1 arguments")
                elif(tokens[1] in addralias):
                    printe(f'Label redeclaration "{tokens[1]}"')
                else:
                    addralias[tokens[1]] = romaddr
                    parse_dd(stringTokenizer(line)[2:], True)
            elif(line.find('.init') != -1):
                if len(tokens) < 2:
                    printe("Excepted > 1 arguments")
                elif(tokens[1] in addralias):
                    printe(f'Label redeclaration "{tokens[1]}"')
                else:
                    addralias[tokens[1]] = ramaddr
                    parse_dd(stringTokenizer(line)[2:], False)
            elif(line.find('.defc') != -1):
                if len(tokens) != 3:
                    printe('Expected 2 arguments')
                elif(tokens[1] in macros):
                    printe(f'Defc redeclaration "{tokens[1]}"')
                else:
                    macros[tokens[1]] = get_number(tokens[2])
                    printv(macros)
            elif(line.find('.export') != -1):
                pass
            else:
                printe('Invalid parameter')

        elif(ltype == linetype.INSTRUCTION):
            if(seg != segment.ROMD):
                printe('Instruction not in rom section')
            else:
                romaddr = romaddr+1
        
        elif(ltype == linetype.LABEL):
            if(seg != segment.ROMD):
                printe('Label not in rom section')
            else:
                if(len(tokens) > 1):
                    printe('Label should not contain whitespaces')
                else:
                    labels[line[:-1]] = romaddr
                    printv(f'Label {line[:-1]} address is {romaddr}')

    if elfexec:
        printv(f'EE: ST1 done. Addr offset for bss {ramaddr}. Last bss-local addr {bssaddr}')
        bssoff = ramaddr
        bssfin = bssaddr
    
    printv(f'Closing file {input_path}')
    input_file.close()

def resolveOffAddr(addr):
    abasen = addr[:addr.find('+')]
    if abasen in addralias:
        if addr[addr.find('+'):] in macros:
            num = addralias[abasen]+macros[addr.find('+'):]
        else:
            num = addralias[abasen]+get_number(addr[addr.find('+'):])
    elif elfexec and abasen in bssmap:
        if addr[addr.find('+'):] in macros:
            num = bssmap[abasen]+macros[addr.find('+'):]+bssoff
        else:
            num = bssmap[abasen]+get_number(addr[addr.find('+'):])+bssoff
    else:
        printe('Invalid address reference (offset detected)')
    return num

def compileFileSecondRun(input_path):
    global romaddr, ramaddr, code, memdata, generated, macros
    global line, linenr, filen, line_nr
    filen = input_path
    printv(f"Generating machine code (compile 2nd run) in {input_path}")
    input_file = open(input_path, "rt")
    seg = segment.ROMD
    for line_nr, line in enumerate(input_file, 1):
        line = prepare_line(line)
        ltype = get_line_type(line)

        tokens = tokenize(line)
        printv(line)
        if(ltype == linetype.INSTRUCTION):
            if tokens[0] in instructions:
                instr = instructions[tokens[0]]
                cinstr = 0
                cinstr = instr.hex
                tokenpos = 1
                opecnt = (1 if instr.pr0 != 0 else 0) +  (1 if instr.pr1 != 0 else 0) +  (1 if instr.pr2 != 0 else 0) +  (1 if instr.pi != 0 else 0)
                if opecnt != len(tokens)-1:
                    printe(f'Expected {opecnt} operands')
                else:
                    if instr.pr0 == 1:
                        cinstr = cinstr | (getreg(tokens[tokenpos])<<7)
                        tokenpos = tokenpos+1
                    if instr.pvjs != 0:
                        cinstr = cinstr | (instr.pvjs<<7)
                    if instr.pr1 == 1:
                        cinstr = cinstr | (getreg(tokens[tokenpos])<<10)
                        tokenpos = tokenpos+1
                    if instr.pr2 == 1:
                        cinstr = cinstr | (getreg(tokens[tokenpos])<<13)
                        tokenpos = tokenpos+1
                    if instr.pi == 2: #addr
                        addr = tokens[tokenpos]
                        resolvaddr = 0
                        if addr[0] == '#':
                            resolvaddr = get_number(addr[1:])
                        elif addr.find('+') != -1:
                            resolvaddr = resolveOffAddr(addr)
                        else:
                            if addr in addralias:
                                resolvaddr = addralias[addr]
                            elif elfexec and addr in bssmap:
                                resolvaddr = bssmap[addr]+bssoff
                            else:
                                resolvaddr = get_number(addr)
  
                        if resolvaddr > 65535 or resolvaddr < 0:
                                #printe('16 bit overflow')
                                pass
                        printv(f'Resolved address {resolvaddr}')
                        cinstr = cinstr | ((resolvaddr&65535)<<16)
                        tokenpos = tokenpos+1
                    if instr.pi == 3: #imm
                        num = 0
                        printv(macros)
                        if tokens[tokenpos] in macros:
                            num = macros[tokens[tokenpos]]
                        elif tokens[tokenpos] in addralias:
                            num = addralias[tokens[tokenpos]]
                        elif elfexec and tokens[tokenpos] in bssmap:
                            num = bssmap[tokens[tokenpos]]+bssoff
                        elif tokens[tokenpos] in labels:
                            num = labels[tokens[tokenpos]]-1
                            printv("NOTE: offsetting [label] const for gcc. when using srs rx->pc address is offset by +1, so tah balances. you probably still want to use that")
                        elif tokens[tokenpos].find('+') != -1:
                            num = resolveOffAddr(tokens[tokenpos])
                        else:
                            num = get_number(tokens[tokenpos])
                        printv(f'Imm={num}')
                        cinstr = cinstr | ((num&65535)<<16)
                        if(num > 65535):
                            printe('16 bit overflow')
                        tokenpos = tokenpos+1
                    if instr.pi == 4:
                        if tokens[tokenpos] not in labels:
                            printe('Unknown label')
                        else:
                            cinstr = cinstr | ((labels[tokens[tokenpos]])<<16)
                            tokenpos = tokenpos+1
            else:
                printe('Opcode not found')
            printv(f'{hex(romaddr)}:{bin(cinstr)[2:].zfill(32)}')
            generated[romaddr] = cinstr
            romaddr = romaddr+1

        elif(ltype == linetype.PARAM):
            if(line.find('.include') != -1):
                if not(tokens[1] in filesinclude):
                    compileFileSecondRun(tokens[1])
            elif(line.find('.global') != -1):
                pass
            elif(line.find('.rod') != -1):
                pass
            elif(line.find('.init') != -1):
                pass
            elif(line.find('.romd') != -1):
                seg = segment.ROMD
            elif(line.find('.ramd') != -1):
                seg = segment.RAMD
            elif(line.find('.org') != -1):
                pass
        #printv(f"RO{romaddr} RA{ramaddr}")
    printv(f'Closing file {input_path}')
    input_file.close()


def tokenize(line):
    return re.split(', | |,', line)

def stringTokenizer(line):
    printv(re.findall('[^\s,"]+|".+?"', line))
    return re.findall('[^\s,"]+|".+?"', line)

def getreg(rs):
    if(rs[0] != 'r'):
        printe('Invalid register')
    num = 0
    try:
        num = int(rs[1])
        if num > 7:
            printe('Invalid register')
    except:
        printe('Invalid register')
    return num


def get_number(num):
    base = 10
    neg = 0
    if num[0] == '-':
        num = num[1:]
        neg = 1
    
    if len(num) >= 3 and num[0] == '0':
        if num[1] == 'x':
            base=16
        elif num[1] == 'b':
            base=2
    #printv(f'Detected number base {base} in {num}')
    try:
        if(base == 10):
            num_int = int(num, base)
        else:
            num_int = int(num[2:], base)
        if neg:
            num_int *= -1
        return num_int
    except:
        printe(f'Number {num} is not valid')
        return -1

def parse_dd(tokens, rom):
    global generated, romaddr, initinfo, ramaddr
    for token in tokens:
        if token[0] == "\"" and token[-1:] == "\"":
            sbytes = bytes(token[1:-1], "ascii").decode("unicode_escape")
            for c in sbytes:
                if rom:
                    generated[romaddr] = ord(c)
                    printv(f"OMem {romaddr}={ord(c)}")
                    romaddr = romaddr+1
                else:
                    initinfo[ramaddr] = ord(c)
                    printv(f"AMem {ramaddr}={ord(c)}")
                    ramaddr = ramaddr+1
                
        else:
            num = get_number(token)
            if num >= (1<<16) or num < -(1<<15):
                printe('16 bit overflow')
            num = num & ((1<<16)-1)
            if rom:
                generated[romaddr] = num
                printv(f"OMem {romaddr}={num}")
                romaddr = romaddr+1
            else:
                initinfo[ramaddr] = num
                printv(f"AMem {ramaddr}={num}")
                ramaddr = ramaddr+1



def get_line_type(line):
    if(len(line) == 0):
        return linetype.EMPTY
    elif(line[0] == '.'):
        return linetype.PARAM
    elif(line.find(':') == len(line)-1):
        return linetype.LABEL
    else:
        return linetype.INSTRUCTION

def prepare_line(line):
    index = 0
    instr = 0
    for c in line:
        if(c == "\""):
            instr += 1
            instr %= 2
        if(c == ";" and instr == 0):
            line = line[:index]
            break
        index += 1

    line = line.strip()
    return line

def make_elf_header(entry=0):
    # todo add shoff
    header = b'\x7f\x45\x4c\x46\x01\x01\x01\x31\x00\x00\x00\x00\x00\x00\x00\x00' + \
             b'\x02\x00\x88\x08\x01\x00\x00\x00'+entry.to_bytes(4, 'little') + \
             b'\x34\x00\x00\x00\x00\x00\x00\x00' +  \
             b'\x00\x00\x00\x00\x34\x00\x20\x00\x02\x00\x00\x00\x00\x00\x00\x00'
    return header

def make_elf_program_header(command, offset, vaddr, paddr, filesz, memsz, flags, align=0x1000):
    assert offset%align == vaddr%align
    paramlist = [command, offset, vaddr, paddr, filesz, memsz, flags, align]
    retbytes = b''
    for x in paramlist:
        retbytes += x.to_bytes(4, 'little')
    return retbytes

verbose = 0

def parseArgs():
    args = sys.argv
    global output_path, verbose, oformat, memmap, elfexec
    output_path = ''
    
    for i, arg in enumerate(args):
        if i == 0 or args[i-1] == "-o":
            continue
        elif arg == "--help":
            help()
            sys.exit(0)
        elif arg == "-o":
            if i+1 == len(args): 
                printes('No output file specified')
            output_path = args[i+1]
        elif arg == "-v":
            verbose = 1
        elif arg == "-b":
            oformat = 1
        elif arg == "-m":
            memmap = 1
        elif arg == "--elf-exec" or arg == "--elfexec":
            elfexec = 1 # generate piOS elf executable. (puts all .global (bss) at end of address space)
                        # to be replaced with proper linker and section management
        else:
            input_paths.append(arg)
    if output_path == '':
        output_path = 'out.hex'

def initInstructions():
    global instructions
    instructions['nop'] = Instruction('nop', 0x00, 0, 0, 0, 0)
    instructions['mov'] = Instruction('mov', 0x01, 1, 1, 0, 0)
    instructions['ldd'] = Instruction('ldd', 0x02, 1, 0, 0, 2)
    instructions['ldo'] = Instruction('ldo', 0x03, 1, 1, 0, 2)
    instructions['ldi'] = Instruction('ldi', 0x04, 1, 0, 0, 3)
    instructions['std'] = Instruction('std', 0x05, 0, 1, 0, 2)
    instructions['sto'] = Instruction('sto', 0x06, 0, 1, 1, 2)
    instructions['add'] = Instruction('add', 0x07, 1, 1, 1, 0)
    instructions['adi'] = Instruction('adi', 0x08, 1, 1, 0, 3)
    instructions['adc'] = Instruction('adc', 0x09, 1, 1, 1, 0)
    instructions['sub'] = Instruction('sub', 0x0A, 1, 1, 1, 0)
    instructions['suc'] = Instruction('suc', 0x0B, 1, 1, 1, 0)
    instructions['cmp'] = Instruction('cmp', 0x0C, 0, 1, 1, 0)
    instructions['cmi'] = Instruction('cmi', 0x0D, 0, 1, 0, 3)
    instructions['jmp'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 0)
    instructions['jca'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 1)
    instructions['jeq'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 2)
    instructions['jlt'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 3)
    instructions['jgt'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 4)
    instructions['jle'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 5)
    instructions['jge'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 6)
    instructions['jne'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 7)
    instructions['jov'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 8)
    instructions['jpr'] = Instruction('jmp', 0x0E, 0, 0, 0, 4, 9)
    instructions['jal'] = Instruction('jal', 0x0F, 1, 0, 0, 4)
    instructions['srl'] = Instruction('srl', 0x10, 1, 0, 0, 3)
    instructions['srs'] = Instruction('srs', 0x11, 0, 1, 0, 3)
    instructions['sys'] = Instruction('sys', 0x12, 0, 0, 0, 0)
    instructions['and'] = Instruction('and', 0x13, 1, 1, 1, 0)
    instructions['orr'] = Instruction('orr', 0x14, 1, 1, 1, 0)
    instructions['xor'] = Instruction('xor', 0x15, 1, 1, 1, 0)
    instructions['ani'] = Instruction('ani', 0x16, 1, 1, 0, 3)
    instructions['ori'] = Instruction('ori', 0x17, 1, 1, 0, 3)
    instructions['xoi'] = Instruction('xoi', 0x18, 1, 1, 0, 3)
    instructions['shr'] = Instruction('shr', 0x1A, 1, 1, 1, 0)
    instructions['shl'] = Instruction('shl', 0x19, 1, 1, 1, 0)
    instructions['cai'] = Instruction('cai', 0x1B, 0, 1, 0, 3)
    instructions['mul'] = Instruction('mul', 0x1C, 1, 1, 1, 0)
    instructions['div'] = Instruction('div', 0x1D, 1, 1, 1, 0)
    instructions['irt'] = Instruction('irt', 0x1E, 0, 0, 0, 0)
    # instructions['plo'] = Instruction('plo', 0x1D, 1, 1, 0, 2)
    instructions['hlt'] = Instruction('hlt', 0x2F, 0, 0, 0, 0)

class Instruction:
    def __init__(self, opcode, hex, pr0, pr1, pr2, pi, pvjs=0):
        self.opcode = opcode
        self.hex = hex
        self.pr0 = pr0
        self.pr1 = pr1
        self.pr2 = pr2
        self.pi = pi
        self.pvjs = pvjs


def printes(msg):
    print(f'\033[0;31m [ERROR] \033[m {msg}')

def printe(msg):
    global errored, error_cnt
    error_cnt = error_cnt + 1
    print(f'\n \033[0;31m [COMPILATION ERROR] \033[mat {filen} @ line {line_nr}')
    print(f'   {msg}')
    print('    ' + line)
    errored = True
    #print(' '*(char_nr+2) + '\033[0;31m^\033[m')


def printv(toprint):
 if verbose:
    print(f'[VERBOSE] {"%.7f" % float(time.time() - start_time)}: {toprint}')

class linetype (Enum):
    EMPTY = 0
    INSTRUCTION = 1
    LABEL = 2
    PARAM = 3

class segment (Enum):
    ROMD = 0
    RAMD = 1

def welcome():
    print("[INFO] pas - pcpu v2 assembler ")
    print("[INFO] Version 1.7 by Piotr Węgrzyn\n")

def help():
    pass

if __name__ == "__main__":
    welcome()
    exit(compileAll())
