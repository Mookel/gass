// 3. SchedWrite(s) (& SchedRead(s))?
def WriteINT : SchedWrite; 
def WriteSHIFT : SchedWrite;
def WriteLOP3 : SchedWrite;
def WriteISETP : SchedWrite;
def WritePRMT : SchedWrite;
def WriteCSR  : SchedWrite;
def WriteNOP  : SchedWrite;

// Integer mulitplication
def WriteIMUL : SchedWrite;
def WriteIMULWIDE : SchedWrite;

// Special units
def WriteF2F : SchedWrite;
def WriteMUFU : SchedWrite;

// Floating points
def WriteFP32 : SchedWrite;
def WriteFP64 : SchedWrite;
def WriteFMNMX : SchedWrite;

// Tensor Cores
def WriteHMMA884 : SchedWrite;
def WriteHMMA16816 : SchedWrite;

// LDST
def WriteLDG : SchedWrite;
def WriteSTG : SchedWrite;
// default width: 32
def WriteLDS : SchedWrite;
def WriteSTS : SchedWrite;
def WriteLDS64 : SchedWrite;
def WriteSTS64 : SchedWrite;
def WriteLDS128: SchedWrite;
def WriteSTS128: SchedWrite;
def WriteLDGSTS : SchedWrite;