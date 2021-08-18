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
line = 0 
line_nr = 0
filen = ''
error_cnt = 0

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

    output_file = open(output_path, "wt")

    if error_cnt == 0:
        for addro, val in generated.items():
            addr = hex(addro)[2:].zfill(4)
            data = hex(val)[2:].zfill(8)
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

    if error_cnt == 0:
        print('\033[0;32m[RESULT]\033[m Compilation finished successfully!')
        exitcode = 0
    else:
        print(f'\033[0;31m[RESULT]\033[m Compilation failed. {error_cnt} errors were found!')
        exitcode = 1
    print(f'[INFO] Compilation time: {"%.5f" % float(time.time() - start_time)} seconds')

    return exitcode

def compileFileFirstRun(input_path):
    global romaddr, ramaddr, addralias, labels, macros
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
                else:
                    printv(f'Global {tokens[1]} address is {ramaddr}')
                    addralias[tokens[1]] = ramaddr
                    if(seg == segment.ROMD):
                        printe('Global declaration in ROM section')
                    else:
                        ramaddr = ramaddr + get_number(tokens[2])
            elif(line.find('.rod') != -1): # use only if no OS - requires access to mem mapping to connect pmem to ram
                if len(tokens) < 2:
                    printe("Excepted > 1 arguments")
                else:
                    addralias[tokens[1]] = romaddr
                    parse_dd(tokens[2:], True)
            elif(line.find('.init') != -1):
                if len(tokens) < 2:
                    printe("Excepted > 1 arguments")
                else:
                    addralias[tokens[1]] = ramaddr
                    parse_dd(tokens[2:], False)
            elif(line.find('.defc') != -1):
                if len(tokens) != 3:
                    printe('Expected 2 arguments')
                else:
                    macros[tokens[1]] = get_number(tokens[2])
                    printv(macros)
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
                
    printv(f'Closing file {input_path}')
    input_file.close()

def compileFileSecondRun(input_path):
    global romaddr, ramaddr, code, memdata, generated, macros
    global line, linenr, filen
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
                    if instr.pvjs != 1:
                        cinstr = cinstr | (instr.pvjs<<7)
                    if instr.pr1 == 1:
                        cinstr = cinstr | (getreg(tokens[tokenpos])<<10)
                        tokenpos = tokenpos+1
                    if instr.pr2 == 1:
                        cinstr = cinstr | (getreg(tokens[tokenpos])<<13)
                        tokenpos = tokenpos+1
                    if instr.pi == 2:
                        addr = tokens[tokenpos]
                        resolvaddr = 0
                        if addr[0] == '#':
                            resolvaddr = get_number(addr[1:])
                        elif addr.find('+') != -1:
                            abasen = addr[:addr.find('+')]
                            printv(abasen)
                            if abasen not in addralias:
                                printe('Invalid address reference (offset detected)')
                            else:
                                if addr[addr.find('+'):] in macros:
                                    resolvaddr = addralias[abasen]+macros[addr.find('+'):]
                                else:
                                    resolvaddr = addralias[abasen]+get_number(addr[addr.find('+'):])
                        else:
                            if addr not in addralias:
                                resolvaddr = get_number(addr)
                             #   printe('Invalid address reference')
                            else:
                                resolvaddr = addralias[addr]
                        if resolvaddr > 65535 or resolvaddr < 0:
                                printe('16 bit overflow')
                        printv(f'Resolved address {resolvaddr}')
                        cinstr = cinstr | ((resolvaddr&65535)<<16)
                        tokenpos = tokenpos+1
                    if instr.pi == 3:
                        num = 0
                        printv(macros)
                        if tokens[tokenpos] in macros:
                            num = macros[tokens[tokenpos]]
                        else:
                            num = get_number(tokens[tokenpos])
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
                ramaddr = ramaddr + get_number(tokens[2])
            elif(line.find('.rod') != -1):
                parse_dd(tokens[2:], True)
            elif(line.find('.init') != -1):
                parse_dd(tokens[2:], False)
            elif(line.find('.romd') != -1):
                seg = segment.ROMD
            elif(line.find('.ramd') != -1):
                seg = segment.RAMD
            elif(line.find('.org') != -1):
                org = get_number(tokens[1])
                if(seg == segment.ROMD):
                    romaddr = org
                else:
                    ramaddr = org
        #printv(f"RO{romaddr} RA{ramaddr}")
    printv(f'Closing file {input_path}')
    input_file.close()


def tokenize(line):
    return re.split(', | |,', line)

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
        return num_int
    except:
        printe(f'Number {num} is not valid')
        return -1

def parse_dd(tokens, rom):
    global generated, romaddr, initinfo, ramaddr
    for token in tokens:
        if token[0] == "\"" and token[-1:] == "\"":
            for c in token[1:-1]:
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
    index = line.find(';')
    if index != -1:
        line = line[:index]
    line = line.lower()
    line = line.strip()
    return line

verbose = 0

def parseArgs():
    args = sys.argv
    global output_path, verbose
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
#    instructions['ret'] = Instruction('ret', 0x10, 0, 0, 0, 0)
#    instructions['psh'] = Instruction('psh', 0x11, 0, 1, 0, 0)
#    instructions['pop'] = Instruction('pop', 0x12, 1, 0, 0, 0)
    instructions['srl'] = Instruction('srl', 0x10, 1, 0, 0, 3)
    instructions['srs'] = Instruction('srs', 0x11, 0, 1, 0, 3)
#    instructions['scl'] = Instruction('scl', 0x15, 0, 0, 0, 2)
#    instructions['trp'] = Instruction('trp', 0x16, 0, 0, 0, 0)
    instructions['and'] = Instruction('and', 0x13, 1, 1, 1, 0)
    instructions['orr'] = Instruction('orr', 0x14, 1, 1, 1, 0)
    instructions['xor'] = Instruction('xor', 0x15, 1, 1, 1, 0)
    instructions['ani'] = Instruction('ani', 0x16, 1, 1, 0, 3)
    instructions['ori'] = Instruction('ori', 0x17, 1, 1, 0, 3)
    instructions['xoi'] = Instruction('xoi', 0x18, 1, 1, 0, 3)
    instructions['shr'] = Instruction('shr', 0x19, 1, 1, 1, 0)
    instructions['shl'] = Instruction('shl', 0x1A, 1, 1, 1, 0)
    instructions['cai'] = Instruction('cai', 0x1B, 0, 1, 0, 3)
    instructions['mul'] = Instruction('mul', 0x1C, 1, 1, 1, 0)
    instructions['div'] = Instruction('div', 0x1D, 1, 1, 1, 0)
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
    print("[INFO] Version 1.4 by Piotr Węgrzyn\n")

def help():
    pass

if __name__ == "__main__":
    welcome()
    exit(compileAll())
