import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../widgets/parcel_card.dart';
import 'parcel_details_screen.dart';
import 'scan_parcel_screen.dart';

class IncomingParcelsScreen extends StatefulWidget {
  static const route = '/incoming';
  const IncomingParcelsScreen({super.key});

  @override
  State<IncomingParcelsScreen> createState() => _IncomingParcelsScreenState();
}

class _IncomingParcelsScreenState extends State<IncomingParcelsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openParcel(Parcel p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ParcelDetailsScreen(parcelId: p.id)),
    );
  }

  Widget _parcelList(List<Parcel> parcels) {
    if (parcels.isEmpty) {
      return Center(
        child: Text(
          'No parcels here yet',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: parcels.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = parcels[i];
        return ParcelCard(
          parcelId: p.id,
          location: p.fromAddress,
          time: formatTime(p.createdAt),
          trailing: p.viewed ? ParcelTrailing.inProgress : ParcelTrailing.newBadge,
          onTap: () => _openParcel(p),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        final newParcels = store.pendingNewParcels;
        final inProgress = store.pendingInProgressParcels;
        final all = store.allPendingParcels;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'Incoming Parcels',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: 'New (${newParcels.length})'),
                Tab(text: 'In Progress (${inProgress.length})'),
                Tab(text: 'All (${all.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _parcelList(newParcels),
              _parcelList(inProgress),
              _parcelList(all),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanParcelScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Scan New Parcel',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
