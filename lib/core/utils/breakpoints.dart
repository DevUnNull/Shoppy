/// Breakpoint tương tự Tailwind (sm/md/lg/xl) để co giãn layout.
abstract final class Breakpoints {
  static const tablet = 600.0;
  static const desktop = 960.0;
  static const wide = 1200.0;

  /// Nội dung trang giới hạn 1200px như Shopee desktop.
  static const maxContentWidth = 1200.0;

  /// Grid 6 cột desktop, tự co về 5/4/3/2 cột.
  static int productColumns(double width) {
    if (width >= wide) return 6;
    if (width >= desktop) return 5;
    if (width >= 760) return 4;
    if (width >= tablet) return 3;
    return 2;
  }
}
