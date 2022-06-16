# quick and ugly glue script to convert from gcc genreated assembly to PAS assembly format

import re
import sys
import math

objects = []
new_lines = []
section = "text"
skip_line = 0
mangled_local_names = {}

def domagic(line, line_nr):
    global skip_line
    if(len(line.strip()) == 0):
        return
    if line.strip()[0] != '.' and skip_line == 0:
        new_lines.append(line)
    skip_line = 0
    line = line.strip()
    conv_insns(line, line_nr)
    if(len(new_lines)>0):
        check_jumps(new_lines[-1].strip())
    corr_sto(line)
    if(line[0] != '.'):
        return
    printv(f"line {line_nr}: {line}")
    if line[0:2] == '.L':
        printv(f"LABELCONV: 'CL{fn}{line[2:]}'")
        new_lines.append(f'CL{fn}{line[2:]}\n')
        return

    check_sections(line)
    parse_common(line)
    collect_objinfo(line, line_nr)

def replace_mangled_params(param):
    if(param.find('+') != -1):
        addrpart = param[:param.find('+')]
        offpart = param[param.find('+'):]
    else:
        addrpart = param
        offpart = ''
    if(mangled_local_names.get(addrpart)):
        addrpart = mangled_local_names[addrpart]
    return addrpart+offpart

def check_jumps(line):
    tokens = tokenize(line)
    if((line[0] == 'j') and tokens[1][0:2]=='.L'):
        new_lines.pop()
        new_lines.append('\t'+tokens[0]+' CL'+fn+tokens[1][2:]+'\n')
    if(line[0:3] == 'ldi' and tokens[2][0:2]=='.L' ):
        new_lines.pop()
        new_lines.append('\t'+tokens[0]+', '+ tokens[1] + ', CL'+fn+tokens[2][2:]+'\n')

def corr_sto(line):
    tokens = tokenize(line)
    if((tokens[0] == 'sto' or tokens[0] == 'ldo') and len(tokens) == 3):
        new_lines.pop()
        new_lines.append('\t' + tokens[0][:-1] + 'd ' + tokens[1] + ', ' + replace_mangled_params(tokens[2]) +'\n')
    if((tokens[0] == 'so8' or tokens[0] == 'lo8') and len(tokens) == 3):
        new_lines.pop()
        new_lines.append('\t' + tokens[0][0] + 'd' + tokens[0][2] + ' ' + tokens[1] + ', ' + replace_mangled_params(tokens[2]) +'\n')

def parse_common(line):
    global mangled_local_names
    if not (line.startswith(".comm")):
        return
    params = tokenize(line)[1:]
    truealign = int(math.log2(int(params[2])))
    # .common declarations from gcc have .local if they are static so we can use it from collect objinfo
    # name mangling is needed for static variables. Non-static are not suppling .global, we need to rely on reset_currobj and defaults
    name = fn+params[0] if curr_obj["outside"] == "local" else params[0]
    if curr_obj["outside"] == "local":
        mangled_local_names[params[0]] = name
    
    objdesc = {"name": name,
               "section": "bss",
               "outside": curr_obj["outside"],
               "size": int(params[1]),
               "align": truealign,
               "gcc_type": "@object",
               "v_type": f'obj:noinit:{curr_obj["outside"]}',
               "data": "<NO>"}
    if (truealign != 1):
        print("ERROR: NOT 16 BIT ALIGNMENTc") 
    objects.append(objdesc)
    reset_currobj() # reset if default.local

def conv_insns(line, line_nr):  
    tokens = tokenize(line)
    templbl = f"\tASMCVTMP{line_nr}:\n"
    if tokens[0] == "j**ce": # VERIFY
        new_lines.pop()
        new_lines.append(f'\tjca {"CL"+fn+tokens[1][2:]}\n\tjeq {"CL"+fn+tokens[1][2:]}\n')
    if tokens[0] == "jge**az": #when equal-no carry
        new_lines.pop()
        new_lines.append(f'\tjca {templbl[1:-2]}\n\tjmp {"CL"+fn+tokens[1][2:]}\n{templbl}')
    if tokens[0] == "jgt**aa": # eqal no carry, so jeq tmp
        new_lines.pop()
        new_lines.append(f'\tjeq {templbl[1:-2]}\n\tjca {templbl[1:-2]}\t\njmp {"CL"+fn+tokens[1][2:]}\n{templbl}')
    if (line[0:3] == 'ldd' or line[0:3] == 'ldi' or line[0:3] == 'std'):
        new_lines.pop()
        new_lines.append('\t'+tokens[0]+' '+tokens[1]+', '+replace_mangled_params(tokens[2])+'\n')
    if line[0:3] == 'adi':
        new_lines.pop()
        new_lines.append('\t'+tokens[0]+' '+tokens[1]+', '+tokens[2]+', '+replace_mangled_params(tokens[3])+'\n')
    # if tokens[0] == "ldo**8" and len(tokens) == 4:
    #     new_lines.pop()
    #     new_lines.append(f'\tldo {tokens[1]}, {tokens[2]}, {tokens[3]}\n')
    #     offset = resolv_8b_addr_offset(tokens[3])
    #     if(offset == 1):
    #         new_lines.append(f'\tldi r4, 8\n\tshr {tokens[1]}, {tokens[1]}, r4\n')
    #     else:
    #         new_lines.append(f'\tani {tokens[1]}, {tokens[1]}, 0xFF\n')
    # if tokens[0] == "ldo**8" and len(tokens) == 3:
    #     new_lines.pop()
    #     new_lines.append(f'\tldd {tokens[1]}, {tokens[2]}\n')
    #     offset = resolv_8b_addr_offset(tokens[2])
    #     if(offset == 1):
    #         new_lines.append(f'\tldi r4, 8\n\tshr {tokens[1]}, {tokens[1]}, r4\n')
    #     else:
    #         new_lines.append(f'\tani {tokens[1]}, {tokens[1]}, 0xFF\n')
    # if tokens[0] == "sto**8" and len(tokens) == 4:
    #     new_lines.pop()
        
    #     offset = resolv_8b_addr_offset(tokens[3])
    #     if(offset == 1):
    #         new_lines.append(f'\n\tldi r4, 8\n\tshl {tokens[1]}, {tokens[1]}, r4\n\tldo r4, {tokens[2]}, {tokens[3]}\n')
    #         new_lines.append(f'\tani r4, r4, 0x00FF\n\torr {tokens[1]}, r4, {tokens[1]}\n\tsto {tokens[1]}, {tokens[2]}, {tokens[3]}\n')
    #     else:
    #         new_lines.append(f'\tldo r4, {tokens[2]}, {tokens[3]}\n')
    #         new_lines.append(f'\tani r4, r4, 0xFF00\n\torr {tokens[1]}, r4, {tokens[1]}\n\tsto {tokens[1]}, {tokens[2]}, {tokens[3]}\n')
    # if tokens[0] == "sto**8" and len(tokens) == 3:
    #     new_lines.pop()
    #     offset = resolv_8b_addr_offset(tokens[2])
    #     if(offset == 1):
    #         new_lines.append(f'\tldi r4, 8\n\tshl {tokens[1]}, {tokens[1]}, r4\n\tldd r4, {tokens[2]}\n')
    #         new_lines.append(f'\tani r4, r4, 0x00FF\n\torr {tokens[1]}, r4, {tokens[1]}\n\tstd {tokens[1]}, {tokens[2]}\n')
    #     else:
    #         new_lines.append(f'\tldd r4, {tokens[2]}\n')
    #         new_lines.append(f'\tani r4, r4, 0xFF00\n\torr {tokens[1]}, r4, {tokens[1]}\n\tstd {tokens[1]}, {tokens[2]}\n')
    if tokens[0] == "gcc**extsgn":
        new_lines.pop()
        new_lines.append(f'\tcai {tokens[1]}, 0x0080\njeq {templbl[1:-2]}\n\tori {tokens[1]}, {tokens[1]}, 0xFF00\n{templbl}')
    if tokens[0] == "a**shr": # CLOBBER
        new_lines.pop()
        cpc = hex(0x8000>>int(tokens[2]))
        orc = hex((0xFFFF<<(16-int(tokens[2])))&0xFFFF)
        new_lines.append(f'\n\tldi r4, {tokens[2]}\n\tshr {tokens[1]}, {tokens[1]}, r4\n\tcai {tokens[1]}, {cpc}\n\tjeq {templbl[1:-2]}\n\tori {tokens[1]}, {tokens[1]}, {orc}\n{templbl}')
    
        

def resolv_8b_addr_offset(cs):
    if cs.find('+') != -1:
        num = int(cs[cs.find('+'):])
        if(num%2 == 0):
            return 0
        else:
            return 1
    else:
        try:
            num = int(cs)
            if(num%2 == 0):
                return 0
            else:
                return 1
        except Exception:
            return 0

def check_sections(line):
    global section
    tokens = tokenize(line)
    if(tokens[0] == ".section"):
        sname = tokens[1]
    else:
        sname = tokens[0]
    if(sname == ".text"):
        section = "text"
    elif(sname == ".bss"):
        section = "bss"
    elif(sname == ".rodata"):
        section = "rodata"
    elif(sname == ".data"):
        section = "data"

curr_obj = {}
size_left = 0
def collect_objinfo(line, line_nr):
    global skip_line
    global size_left
    params = tokenize(line)
    #print(params)
    #print(section)
    if line.startswith(".p2align"):
        if (params[1] != "1"): # gcc converts 32 bit ok! but check 8 bit when implemented. and/shift in code or [force 16 bit align (and 8 bit internal)]
            print("ERROR: NOT 16 BIT ALIGNMENT") 
    if line.startswith(".type"):
        curr_obj["name"] = params[1]
        if curr_obj["outside"] == "local":
            curr_obj["name"] = fn+curr_obj["name"]
        curr_obj["gcc_type"] = params[2]
        if(params[2] == "@function"):
            curr_obj["section"] = section
            objects.append(curr_obj)
            reset_currobj()
        elif(params[2] == "@object"):
            pass
        else:
            print("ERR TYPE")
    #print(curr_obj)
    if line.startswith(".local"):
        curr_obj["outside"] = "local"
    if line.startswith(".global"):
        curr_obj["outside"] = "export"
    if line.startswith(".size") and curr_obj["gcc_type"] == "@object":
        curr_obj["size"] = params[2]
        curr_obj["section"] = section
        size_left = int(params[2])
        skip_line = 1
        if(section == "bss"):
            objects.append(curr_obj)
            reset_currobj()
    
    if(line.startswith(".short")):
        size_left -= 2
        curr_obj["data"] = curr_obj["data"]+f"{int(params[1])&0x00ff},{int(params[1])>>8}," # memory now is addressed by 8 bit (LE)
        if(size_left == 0):
            curr_obj["data"] = curr_obj["data"][4:-1]
            objects.append(curr_obj)
            reset_currobj()
        if(size_left < 0):
            print("SIZE ERROR!!! (CHECK .size and .string/.short OR data in .text)")
    if(line.startswith(".byte")):
        size_left -= 1
        curr_obj["data"] = curr_obj["data"]+params[1]+"," 
        if(size_left == 0):
            curr_obj["data"] = curr_obj["data"][4:-1]
            objects.append(curr_obj)
            reset_currobj()
        if(size_left < 0):
            print("SIZE ERROR!!! (CHECK .size and .string/.short OR data in .text)")
    if(line.startswith(".zero")):
        cnt = int(params[1])
        size_left -= cnt
        for i in range(cnt):
            curr_obj["data"] = curr_obj["data"]+"0,"
        if(size_left == 0):
            curr_obj["data"] = curr_obj["data"][4:-1]
            objects.append(curr_obj)
            reset_currobj()
        if(size_left < 0):
            print("SIZE ERROR!!! (CHECK .size and .string/.short OR data in .text)")
    if(line.startswith(".string")):
        params[1] = line[line.find("\""):]
        if(new_lines[-1][0:2] == 'CL' and section == "rodata"): # workaround for string declared as labels
            curr_obj["name"] = new_lines[-1][:-2]
            new_lines.pop()
            curr_obj["section"] = "rodata"
            curr_obj["size"] = len(params[1])-1
            curr_obj["gcc_type"]="@object"
            curr_obj["v_type"] = "lblstr"
            curr_obj["data"] = params[1]+",0" # null terminated
            objects.append(curr_obj)
            reset_currobj()
        else:
            size_left -= len(params[1])+1-2
            curr_obj["data"] = curr_obj["data"]+params[1]+",0,"
            if(size_left == 0):
                curr_obj["data"] = curr_obj["data"][4:-1]
                objects.append(curr_obj)
                reset_currobj()
            if(size_left < 0):
                print("SIZE ERROR!!! (CHECK .size and .string/.short OR data in .text)")
                exit(1)

def reset_currobj():
    global curr_obj
    curr_obj = {
    "name": "<NO>",
    "section": "<NO>",
    "outside": "global",
    "size": "<NO>",
    "align": "1",
    "gcc_type": "<NO>",
    "v_type": "<NO>",
    "data": "<NO>"
    }

def printv(text):
    #print(f'[VERBOSE]: {text}')
    pass

def tokenize(line):
    return re.split(', | |,|\t|\n|\t ', line)

def asm_print_objects():
    print("; functions")
    for obj in objects:
        if obj["gcc_type"] == "@function":
            print(f".export {obj['name']}")
    print(".ramd")
    print("; rodata")
    for obj in objects:
        if obj["gcc_type"] == "@object" and obj["section"]=="rodata":
            if(obj["outside"] == "export"):
                print(f".export {obj['name']}")
            #print(f".init {obj['name']}, {int(obj['size'])>>1}, {obj['data']}")
            print(f".init {obj['name']}, {obj['data']}")
    print("; data")
    for obj in objects:
        if obj["gcc_type"] == "@object" and obj["section"]=="data":
            if(obj["outside"] == "export"):
                print(f".export {obj['name']}")
            #print(f".init {obj['name']}, {int(obj['size'])>>1}, {obj['data']}")
            print(f".init {obj['name']}, {obj['data']}")
    print("; bss")
    for obj in objects:
        if obj["gcc_type"] == "@object" and obj["section"]=="bss":
            if(obj["outside"] == "export"):
                print(f".export {obj['name']}")
            #print(f".global {obj['name']}, {int(obj['size'])>>1}")
            print(f".global {obj['name']}, {int(obj['size'])}") # temporary dont shift becoause compiler don't divide offset/addr so size *2 [FIXME]

if __name__ == "__main__":
    #file = open('/home/piotro/opt/pcputb/jumptable.s', 'r')
    file = open(sys.argv[1], 'r')
    global fn
    fn = file.name
    lines = file.readlines()
    reset_currobj()
    line_nr = 0
    print(".romd")
    for line in lines:
        domagic(line, line_nr)
        line_nr += 1
    if(size_left > 0):
        print("SIZE ERROR (REACHED EOF)")
    #print(objects)
    for line in new_lines:
        print(line, end="")
    asm_print_objects()
    file.close()