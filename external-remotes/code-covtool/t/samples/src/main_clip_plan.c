/*
 * Драйвер для генерации coverage/clip_plan.LCOV (t/samples/scripts/generate_coverage.pl).
 * Один вызов на каждый TU без собственного main() из flat_*, backend/br_*, utils/u_*.
 */
void only_flat(void);
void fa(void);
void fb(void);
void x1(void);
void x2(void);
void x3(void);
void br_solo(void);
void br_a(void);
void br_b(void);
void br_m1(void);
void br_m2(void);
void br_m3(void);
void u_extra(void);
void u_more(void);

int main(void) {
  only_flat();
  fa();
  fb();
  x1();
  x2();
  x3();
  br_solo();
  br_a();
  br_b();
  br_m1();
  br_m2();
  br_m3();
  u_extra();
  u_more();
  return 0;
}
