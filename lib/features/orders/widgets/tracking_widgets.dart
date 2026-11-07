import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/order.dart';

/// Thanh 4 mốc: Đã đặt -> Chờ ĐVVC lấy -> Đang giao -> Giao thành công.
class TrackingStepper extends StatelessWidget {
  const TrackingStepper({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final reached = order.reachedMilestone;
    const milestones = TrackingMilestone.values;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final circle = compact ? 44.0 : 60.0;
        return Stack(
          children: [
            // Đường nối giữa các mốc.
            Positioned(
              top: circle / 2 - 2,
              left: constraints.maxWidth / 8,
              right: constraints.maxWidth / 8,
              child: Row(
                children: [
                  for (var i = 0; i < milestones.length - 1; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        color: i < reached
                            ? AppColors.success
                            : AppColors.border,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in milestones)
                  Expanded(
                    child: _Milestone(
                      milestone: m,
                      done: m.index <= reached,
                      size: circle,
                      time: m.index <= reached ? order.milestoneTime(m) : null,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Milestone extends StatelessWidget {
  const _Milestone({
    required this.milestone,
    required this.done,
    required this.size,
    this.time,
  });

  final TrackingMilestone milestone;
  final bool done;
  final double size;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: done ? AppColors.success : AppColors.border,
              width: 4,
            ),
          ),
          child: Icon(
            milestone.icon,
            size: size * 0.45,
            color: done ? AppColors.success : AppColors.border,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          milestone.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: done ? AppColors.title : AppColors.caption,
          ),
        ),
        if (time != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              formatDateTime(time!),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.caption),
            ),
          ),
      ],
    );
  }
}

/// Nhật ký hành trình: mới nhất ở trên, chấm xanh cho bản ghi mới nhất.
class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({super.key, required this.steps});

  final List<TrackingStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Text(
        'Chưa có thông tin hành trình.',
        style: TextStyle(color: AppColors.caption),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 140,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      steps[i].createdAt == null
                          ? '—'
                          : formatDateTime(steps[i].createdAt!),
                      style: TextStyle(
                        fontSize: 13,
                        color: i == 0 ? AppColors.success : AppColors.caption,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: i == 0 ? 12 : 8,
                        height: i == 0 ? 12 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == 0 ? AppColors.success : AppColors.border,
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(width: 1, color: AppColors.border),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].description.isEmpty
                              ? steps[i].status
                              : steps[i].description,
                          style: TextStyle(
                            color: i == 0 ? AppColors.success : AppColors.body,
                            fontWeight: i == 0 ? FontWeight.w500 : null,
                          ),
                        ),
                        if (steps[i].location != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              steps[i].location!,
                              style: const TextStyle(
                                color: AppColors.caption,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Đường viền sọc xanh - đỏ đặc trưng của Shopee (mép trên card địa chỉ).
class AirmailStripe extends StatelessWidget {
  const AirmailStripe({super.key, this.height = 3});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _StripePainter()),
  );
}

class _StripePainter extends CustomPainter {
  static const _red = Color(0xFFF18D9B);
  static const _blue = Color(0xFF6FA6D6);

  @override
  void paint(Canvas canvas, Size size) {
    const segment = 41.0; // 33px màu + 8px trắng, lặp lại
    canvas.clipRect(Offset.zero & size);
    var x = -size.height;
    var i = 0;
    while (x < size.width) {
      final paint = Paint()..color = i.isEven ? _red : _blue;
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + 33, 0)
        ..lineTo(x + 33, size.height)
        ..close();
      canvas.drawPath(path, paint);
      x += segment;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
