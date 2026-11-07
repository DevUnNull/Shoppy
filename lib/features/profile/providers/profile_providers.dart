import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../partner/services/partner_service.dart';
import '../services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(apiClientProvider)),
);

final partnerServiceProvider = Provider<PartnerService>(
  (ref) => PartnerService(ref.watch(apiClientProvider)),
);
