class GASSReg<string n, bits<16> enc> : Register<n> {
  let Namespace = "GASS";
  let HWEncoding = enc;
}

class GASSRegClass<list<ValueType> regTypes, int alignment, dag regList>
  : RegisterClass<"GASS", regTypes, alignment, regList>;

let Namespace = "GASS" in {
  def sub0 : SubRegIndex<32>;
  def sub1 : SubRegIndex<32>;
  def sub2 : SubRegIndex<32>;
  def sub3 : SubRegIndex<32>;
  // 16-bit un-allocatable sub regs
  def lo : SubRegIndex<32>;
  def hi : SubRegIndex<32>;
  // 8-bit byte-view
  // def b0 : 
  // def b1 :
  // def b2 :
  // def b3 :
}

// Uniform Datapath Registers
// 0-3 are reserved (?)
foreach Index = 4-63 in {
  def SGPR#Index : GASSReg<"UR"#Index, Index>;
}

// 16-bit un-allocatable sub regs
foreach Index = 0-255 in {
  def VGPR#Index#_LO : GASSReg<"R"#Index#"_LO", 0>;
  def VGPR#Index#_HI : GASSReg<"R"#Index#"_HI", 0>;
}

foreach Index = 0-255 in {
  def VGPR#Index : GASSReg<"R"#Index, Index> {
    let SubRegs = [!cast<GASSReg>("VGPR"#Index#"_LO"), 
                   !cast<GASSReg>("VGPR"#Index#"_HI")];
    let SubRegIndices = [lo, hi];
  }
}

foreach Index = 0-6 in {
  def PR#Index : GASSReg<"P"#Index, Index>;
  def UPR#Index : GASSReg<"UP"#Index, Index>;
}

// Zero registers
def PT   : GASSReg<"PT", 0x7>;
foreach SubName = ["_LO", "_HI"] in {
  def RZ16#SubName : GASSReg<"RZ16"#SubName, 0xff>;
  def RZ16_1#SubName : GASSReg<"RZ16_1"#SubName, 0xff>;
}
def RZ32 : GASSReg<"RZ", 0xff> {
  let SubRegs = [RZ16_LO, RZ16_HI];
  let SubRegIndices = [lo, hi];
}
def UPT : GASSReg<"UPT", 0x7>;
def URZ32 : GASSReg<"URZ", 0x3f>;

// this should never be used
def RZ32_1 : GASSReg<"RZ32_1", 0xff> {
  let SubRegs = [RZ16_1_LO, RZ16_1_HI];
  let SubRegIndices = [lo, hi];
}
def RZ64 : GASSReg<"RZ", 0xff> {
  let SubRegIndices = [sub0, sub1];
  let SubRegs = [RZ32, RZ32_1];
}

// Vector registers
// Following the practice in AMDGPU (SIRegisterInfo.td)
// Generates list of sequential register tuple names.
// E.g. RegSeq<3,2,2,"s">.ret -> [ "s[0:1]", "s[2:3]" ]
class RegSeqNames<int last_reg, int stride, int size, string prefix,
                  int start = 0> {
  int next = !add(start, stride);
  int end_reg = !add(start, size, -1);
  list<string> ret =
    !if(!le(end_reg, last_reg),
        !listconcat([prefix # "[" # start # ":" # end_reg # "]"],
                    RegSeqNames<last_reg, stride, size, prefix, next>.ret),
                    []);
}

// Generates list of dags for register tupless.
class RegSeqDags<RegisterClass RC, int last_reg, int stride, int size,
                int start = 0> {
  dag trunc_rc = (trunc RC,
                  !if(!and(!eq(stride, 1), !eq(start, 0)),
                      !sub(!add(last_reg, 2), size),
                      !add(last_reg, 1)));
  list<dag> ret =
    !if(!lt(start, size),
        !listconcat([(add (decimate (shl trunc_rc, start), stride))],
                    RegSeqDags<RC, last_reg, stride, size, !add(start, 1)>.ret),
        []);
}

class GASSRegTuples<list<SubRegIndex> Indices, RegisterClass RC,
                    int last_reg, int stride, int size, string prefix>
  : RegisterTuples<Indices, 
                   RegSeqDags<RC, last_reg, stride, size>.ret,
                   RegSeqNames<last_reg, stride, size, prefix>.ret>;


// Register Classes
def VReg1  : GASSRegClass<[i1], 1, (add (sequence "PR%u", 0, 6), PT)>; 

// Each VReg32 has 2 sub registers: [lo, hi]
// All registers are:
//   vgpr0_lo, vgpr0_hi, vgpr1_lo, vgpr1_hi, vgpr2_lo, vgpr2_hi, ...
def VReg32 : GASSRegClass<[i32,f32,v2f16, v2i16, f16, i16], 
                           32, (add (sequence "VGPR%u", 0, 255), RZ32, RZ32_1)> {
  let AllocationPriority = 1;
}

// def : RegisterWithSubRegs<"", 
//                           [VREG0, VREG1], [VREG2, VREG3], ...>;
def VReg64Tuple : GASSRegTuples<[sub0, sub1], VReg32, 255, 2, 2, "R">;
// Subregister indices:
//   hi, lo
//   sub0, sub1
//   sub1_then_lo, sub1_then_hi
def VReg64 : GASSRegClass<[i64, f64, v2f32, v2i32, v4f16], 64, 
                          (add VReg64Tuple, RZ64)> {
  let AllocationPriority = 2;
  let GeneratePressureSet = false;
}
def VReg128Tuple : GASSRegTuples<[sub0, sub1, sub2, sub3], 
                                 VReg32, 255, 4, 4, "R">;
def VReg128 : GASSRegClass<[v2i64, v2f64, v4i32, v4f32, 
                            v8f16, v8i16, i128, f128], 128, 
                           (add VReg128Tuple)> {
  let AllocationPriority = 3;
  let GeneratePressureSet = false;
}

// Uniform Registers
def SReg1 : GASSRegClass<[i1], 1, (add (sequence "UPR%u", 0, 6), UPT)>;
def SReg32 : GASSRegClass<[i32], 32, (add (sequence "SGPR%u", 4, 63), URZ32)>;

def SReg64Tuple : GASSRegTuples<[sub0, sub1], SReg32, 63, 2, 2, "UR">;
// TODO: URZ
def SReg64 : GASSRegClass<[i64, v2i32], 64, (add SReg64Tuple)>;

//=--------------------------------------------------------------------------=//
// Virtual registers (will be eliminated after ISel)
//=--------------------------------------------------------------------------=//
class GASSVirtRegClass<list<ValueType> regTypes, int alignment, dag regList>
  : GASSRegClass<regTypes, alignment, regList> {
  let isAllocatable = false;
  let GeneratePressureSet = false;
}
def VReg16 : GASSVirtRegClass<[f16], 16, 
    (add (sequence "VGPR%u_LO", 0, 255), (sequence "VGPR%u_HI", 0, 255), 
    RZ16_LO, RZ16_HI, RZ16_1_LO, RZ16_1_HI)>;
def VReg16Lo : GASSVirtRegClass<[f16], 16, (add (sequence "VGPR%u_LO", 0, 255), RZ16_LO, RZ16_1_LO)>;
def VReg16Hi : GASSVirtRegClass<[f16], 16, (add (sequence "VGPR%u_HI", 0, 255), RZ16_HI, RZ16_1_HI)>;
//=--------------------------------------------------------------------------=//