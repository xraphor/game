typedef unsigned char u8;
typedef unsigned short u16;
static volatile u16 *const screen=(u16*)0xb8000;
static unsigned pos;
static u8 inb(u16 p){u8 v; __asm__ volatile("inb %1,%0":"=a"(v):"Nd"(p)); return v;}
static void clear(void){for(unsigned i=0;i<2000;i++)screen[i]=0x0f20;pos=0;}
static void put(char c){
 if(c=='\n')pos=(pos/80+1)*80;
 else if(c=='\b'){if(pos){--pos;screen[pos]=0x0f20;}}
 else screen[pos++]=0x0f00|(u8)c;
 if(pos>=2000){for(unsigned i=0;i<1920;i++)screen[i]=screen[i+80];for(unsigned i=1920;i<2000;i++)screen[i]=0x0f20;pos-=80;}
}
static void print(const char*s){while(*s)put(*s++);}
static int eq(const char*a,const char*b){while(*a&&*a==*b){a++;b++;}return *a==*b;}
static const char keys[128]={
 [2]='1',[3]='2',[4]='3',[5]='4',[6]='5',[7]='6',[8]='7',[9]='8',[10]='9',[11]='0',
 [14]='\b',[16]='q',[17]='w',[18]='e',[19]='r',[20]='t',[21]='y',[22]='u',[23]='i',[24]='o',[25]='p',
 [28]='\n',[30]='a',[31]='s',[32]='d',[33]='f',[34]='g',[35]='h',[36]='j',[37]='k',[38]='l',
 [44]='z',[45]='x',[46]='c',[47]='v',[48]='b',[49]='n',[50]='m',[57]=' '
};
void kernel_main(void){
 clear();print("NUKE CORE 0.1 - nucleo experimental proprio\n");
 print("Digite help para comandos. Teclado basico sem Shift.\n\n> ");
 char line[128];unsigned n=0;int extended=0;
 for(;;){
  if(!(inb(0x64)&1)){__asm__ volatile("pause");continue;}
  u8 k=inb(0x60);
  if(k==0xe0||k==0xe1){extended=1;continue;}
  if(extended){extended=0;continue;}
  if(k&0x80)continue;
  char c=keys[k];
  if(!c)continue;
  if(c=='\b'){if(n){n--;put(c);}continue;}
  if(c=='\n'){
   line[n]=0;put('\n');
   if(eq(line,"help"))print("help - comandos\nclear - limpar\nabout - sistema\nhalt - parar\n");
   else if(eq(line,"clear"))clear();
   else if(eq(line,"about"))print("Nucleo x86 32-bit proprio. Nao e Linux. Sem rede ou disco.\n");
   else if(eq(line,"halt")){print("CPU parada. Feche o emulador.\n");for(;;)__asm__ volatile("hlt");}
   else if(n)print("Comando desconhecido. Digite help.\n");
   n=0;print("> ");
  }else if(n<sizeof(line)-1){line[n++]=c;put(c);}
 }
}
