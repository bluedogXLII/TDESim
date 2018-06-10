void main() {
  for (double a = 1.0; a <= 19.0; a++)
    for (double p = 1.0; p <= 19.0; p++)
      for (double s = 3.5; s <= 20.5; s++) {
        double n = 1 / 400 * a * p * s;
        //a-w-f=1
        if (sawf(a, p, s) > n &&
            0 <= wawf(a, p, s) &&
            wawf(a, p, s) <= 18 &&
            0 <= fawf(a, p, s) &&
            fawf(a, p, s) <= 19 - p &&
            //(sawf(a, p, s) > sw0(a, p, s) || fw0(a, p, s) > 19 - p) &&
            (sawf(a, p, s) > sf0(a, p, s) || wf0(a, p, s) > a - 1))
          print(
              'a: $a, p: $p, s: $s, w: ${wawf(a, p, s)}, f: ${fawf(a, p, s)}, sawf: ${sawf(a, p, s)}, n: $n');
        //p-f=1a
        if (spf(a, p, s) > n &&
            0 <= wpf(a, p, s) &&
            0 <= fpf(a, p, s) &&
            a - wpf(a, p, s) - fpf(a, p, s) >= 1 &&
            //(spf(a, p, s) > sw0(a, p, s) || fw0(a, p, s) > 19 - p) &&
            (spf(a, p, s) > sf0(a, p, s) || wf0(a, p, s) > a - 1))
          print(
              'a: $a, p: $p, s: $s, w: ${wpf(a, p, s)}, f: ${fpf(a, p, s)}, spf: ${spf(a, p, s)}, n: $n');
        if (sw0(a, p, s) > sf0(a, p, s) &&
            fw0(a, p, s) < 19 - p &&
            fw0(a, p, s) < a - 1 &&
            fw0(a, p, s) >= 0 &&
            wf0(a, p, s) >= 0 &&
            wf0(a, p, s) < a - 1)
          print(
              'a: $a, p: $p, s: $s, w: ${wf0(a, p, s)}, f: ${fw0(a, p, s)}, sw0: ${sw0(a, p, s)}, sf0: ${sf0(a, p, s)}, n: $n');
      }
}

double sawf(double a, double p, double s) =>
    (a + p + s - 1) * (a + p + s - 1) / 1600;

double wawf(double a, double p, double s) => 1 / 2 * (a + p - s - 1);

double fawf(double a, double p, double s) => 1 / 2 * (a - p + s - 1);

double spf(double a, double p, double s) =>
    19 * (a + p + s - 19) * (a + p + s - 19) / 1600;

double wpf(double a, double p, double s) => 1 / 2 * (a + p - s - 19);

double fpf(double a, double p, double s) => 19 - p;

double sw0(double a, double p, double s) => s * (a + p) * (a + p) / 1600;

double fw0(double a, double p, double s) => 1 / 2 * (a - p);

double sf0(double a, double p, double s) => p * (a + s) * (a + s) / 1600;

double wf0(double a, double p, double s) => 1 / 2 * (a - s);
