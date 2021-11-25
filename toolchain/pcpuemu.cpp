#include <bits/stdc++.h>
using namespace std;

const int RAM_SIZE = (1<<16);

short ram[RAM_SIZE];
unsigned int rom[RAM_SIZE];

struct state {
    unsigned short r[8] = {0,0,0,0,0,0,0,0};
    unsigned short pc = 0;
    int state_result = 0;
} state;

void dump_state(){
    for(int i=0; i<8; i++){
        cout<<"r"<<i<<':'<<state.r[i]<<' ';
    }
    cout<<"pc:"<<state.pc;
    cout<<'\n';
}

void dump_screen(){
    cout<<"->";
    int addrp = 0x1000;
    for(int i=0; i<20; i++) { //FIXME
        for(int j=0; j<105; j++) {
            if(!ram[addrp])
                cout<<' ';
            cout<<(char)(ram[addrp]&0xFF);
            addrp++;
        }
    }
    cout<<"<-\n";
}

int opc = 0;

bool step = false;
void execute_op(){
    unsigned int instr = rom[state.pc];
    int opcode = instr & 0x7F;
    short ia = instr>>16;
    int tg = (instr>>7)&0b111;
    int fo = (instr>>10)&0b111;
    int so = (instr>>13)&0b111;
    int lr = ram[19518];
    cout<<"Executing ";
    state.pc++;
    if(opcode == 0x0){ 
        cout<<"NOP ";
    } else if (opcode == 0x1){
        cout<<"MOV tg=r"<<tg<<" fo=r"<<fo; 
        state.r[tg] = state.r[fo];
    } else if (opcode == 0x2){
        cout<<"LDD a="<<ia<<" [v]="<<ram[ia]<<" tg=r"<<tg;
        state.r[tg] = ram[ia];
    } else if (opcode == 0x3){
        cout<<"LDO [v]="<<ram[state.r[fo]+ia]<<" tg=r"<<tg<<" fo=r"<<fo<<" [fo]="<<state.r[fo]<<"+off("<<ia<<")="<<state.r[fo]+ia;
        state.r[tg] = ram[state.r[fo]+ia];
    } else if (opcode == 0x4){
        cout<<"LDI i="<<ia<<" tg=r"<<tg;
        state.r[tg] = ia;
    } else if (opcode == 0x5){
        cout<<"STD a="<<ia<<" fo=r"<<fo<<" [fo]="<<state.r[fo];
        ram[ia] = state.r[fo];
    } else if (opcode == 0x6){
        cout<<"STO fo=r"<<fo<<" [fo]="<<state.r[fo]<<" so=r"<<so<<" [so]="<<state.r[so]<<"+off("<<ia<<")="<<state.r[so]+ia;
        ram[state.r[so]+ia]= state.r[fo];
    } else if (opcode == 0x7){
        cout<<"ADD tg="<<tg<<" fo="<<fo<<" so="<<so;
        state.state_result = (int)state.r[fo] + (int)state.r[so];
        state.r[tg] = state.r[fo] + state.r[so];
    } else if (opcode == 0x8){
        cout<<"ADI tg="<<tg<<" fo="<<fo<<" i="<<ia;
        state.state_result = (int)state.r[fo] + (int)ia;
        state.r[tg] = state.r[fo] + ia;
    } else if (opcode == 0x9){
        cout<<"ADC tg="<<tg<<" fo="<<fo<<" so="<<so;
        if(state.state_result & (1<<17)){
            cout<<"[TAKEN]";
            state.state_result = (int)state.r[fo] + (int)state.r[so];
            state.r[tg] = state.r[fo] + state.r[so];
        } else
            cout<<"[NOT TAKEN]";
    } else if (opcode == 0xA){
        cout<<"SUB tg="<<tg<<" fo="<<fo<<" so="<<so;
        state.state_result = (int)state.r[fo] - (int)state.r[so];
        state.r[tg] = state.r[fo] - state.r[so];
    } else if (opcode == 0xB){
         cout<<"SUC tg="<<tg<<" fo="<<fo<<" so="<<so;
        if(!(state.state_result & (1<<17))){
            cout<<"[TAKEN]";
            state.state_result = (int)state.r[fo] - (int)state.r[so];
            state.r[tg] = state.r[fo] - state.r[so];
        } else
            cout<<"[NOT TAKEN]";
    } else if (opcode == 0xC){
        cout<<"CMP fo="<<fo<<" so="<<so<<" res="<<state.r[fo]-state.r[so];
        state.state_result = (int)state.r[fo] - (int)state.r[so];
    } else if (opcode == 0xD){
        cout<<"CMI fo="<<fo<<" i="<<ia<<" res="<<state.r[fo]-ia;
        state.state_result = (int)state.r[fo] - (int)ia;
    } else if (opcode == 0xE){
        int cond_code = (instr >> 7) & 0b1111;
        cout<<"JMP condcode="<<cond_code<<" jaddr="<<ia<<" sr="<<state.state_result;
        if((cond_code == 0x0) |
            (cond_code == 0x1 && (state.state_result & (1<<17))) ||
            (cond_code == 0x2 && (state.state_result == 0)) ||
            (cond_code == 0x3 && (state.state_result < 0 )) ||
            (cond_code == 0x4 && (state.state_result > 0)) ||
            (cond_code == 0x5 && (state.state_result <= 0)) ||
            (cond_code == 0x6 && (state.state_result >= 0)) ||
            (cond_code == 0x7 && (state.state_result != 0)) ){
            cout << " [TAKEN]";
            state.pc = ia;
        } else {
            cout << " [NOT TAKEN]";
        }
    } else if (opcode == 0xF){
        cout<<"JAL jaddr="<<ia<<" tg=r"<<tg;
        state.r[tg] = state.pc;
        state.pc = ia;

    } else if (opcode == 0x10 && ia == 0) {
        cout<<"SRL PC tg=r"<<tg;
        state.r[tg] = state.pc;
    } else if (opcode == 0x11 && ia == 0) {
        cout<<"SRS PC fo=r"<<fo;
        state.pc = state.r[fo];
    } else if (opcode == 0x13){
        cout<<"AND tg="<<tg<<" fo="<<fo<<" so="<<so;
        state.state_result = state.r[fo] & state.r[so];
        state.r[tg] = state.r[fo] & state.r[so];
    } else if (opcode == 0x14){
        cout<<"ORR tg="<<tg<<" fo="<<fo<<" so="<<so;
        state.state_result = state.r[fo] | state.r[so];
        state.r[tg] = state.r[fo] | state.r[so];
    } else if (opcode == 0x15){
        cout<<"XOR tg="<<tg<<" fo="<<fo<<" so="<<so;
        state.state_result = state.r[fo] ^ state.r[so];
        state.r[tg] = state.r[fo] ^ state.r[so];
    } else if (opcode == 0x16){
        cout<<"ANI tg="<<tg<<" fo="<<fo<<" i="<<ia;
        state.state_result = state.r[fo] & ia;
        state.r[tg] = state.r[fo] & ia;
    } else if (opcode == 0x17){
        cout<<"ORI tg="<<tg<<" fo="<<fo<<" i="<<ia;
        state.state_result = state.r[fo] | ia;
        state.r[tg] = state.r[fo] | ia;
    } else if (opcode == 0x18){
        cout<<"XOI tg="<<tg<<" fo="<<fo<<" i="<<ia;
        state.state_result = state.r[fo] ^ ia;
        state.r[tg] = state.r[fo] ^ ia;
    } else if (opcode == 0x19){
        cout<<"SHL tg="<<tg<<" fo="<<fo<<" so="<<so;
        state.r[tg] = state.r[fo]<<state.r[so];
        state.state_result = state.r[fo]<<state.r[so];
    } else if (opcode == 0x1A){
        cout<<"SHR tg="<<tg<<" fo="<<fo<<" so="<<so;
        state.state_result = state.r[fo]>>state.r[so];
        state.r[tg] = state.r[fo]>>state.r[so];
    } else if (opcode == 0x1B){
        cout<<"CAI tg="<<tg<<" fo="<<fo<<" i="<<ia<<" res="<<(state.r[fo]&ia);
        state.state_result = state.r[fo] & ia;
    } else if (opcode == 0x1C){
        cout<<"MUL tg="<<tg<<" fo="<<fo<<" so="<<so;
        state.state_result = (unsigned short)state.r[fo]*(unsigned short)state.r[so];
        state.r[tg] = (unsigned short)state.r[fo]*(unsigned short)state.r[so];
    } else if (opcode == 0x1D){
        cout<<"DIV tg="<<tg<<" fo="<<fo<<" so="<<so;
        state.state_result =  (unsigned short)state.r[fo]/(unsigned short)state.r[so];
        state.r[tg] =  (unsigned short)state.r[fo]/(unsigned short)state.r[so];
    } else {
        cerr<<"UNKNOWN INSTR opcode="<<opcode<<'\n';
        if(instr==0xCAFE)
            return;
        assert(opcode != opcode);
    }
    cout<<'\n';
     
    dump_state();
     if(state.pc==175){
        //dump_screen();
        step = true;
        
    }
    /* manual debugging
    if(opc++ == 10000){
         dump_screen();getc_unlocked(stdin);
         opc=0;
    }
    if(state.pc==18){
        cout<<"R:"<<ram[19578]<<' '<<ram[19580];
        dump_screen();
        step = true;
        
    }

    if(step || ram[19518] == -1 || ram[19518] != lr){
        getc_unlocked(stdin);
    }
    */

    if(step){
        getc_unlocked(stdin);
    }
}

// :04 0013 00 00040204 DF
void load_program(ifstream& file){
    string line;
    while(file>>line){
        if(line == ":00000001FF")
            break;
        assert(line[0] == ':');
        string addrs = line.substr(3, 4);
        int addr = stoi(addrs, nullptr, 16);
        unsigned int val = stoul(line.substr(9, 8), nullptr, 16);
        cout<<"LOAD "<<addr<<' '<<val<<'\n';
        rom[addr] = val;
    }
}

int main(int argc, char* argv[]){
    string file_path = argv[1];
    ifstream file;
    file.open(file_path);
    load_program(file);
    while(true){
        execute_op();
    }
}