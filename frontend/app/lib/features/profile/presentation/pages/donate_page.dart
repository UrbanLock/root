import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/profile/presentation/pages/donate_form_page.dart';
import 'package:app/features/profile/presentation/pages/donation_detail_page.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/profile/domain/models/donation.dart';

/// Pagina che mostra lo storico delle donazioni e permette di effettuare una nuova donazione
/// 
/// Mostra tutte le donazioni effettuate dall'utente con:
/// - Foto dell'oggetto
/// - Nome dell'oggetto
/// - Categoria
/// - Data di donazione
/// - Stato (in attesa, pubblicata, ecc.)
/// 
/// **TODO quando il backend sarà pronto:**
/// - Caricare storico dal backend (GET /api/v1/donations)
/// - Paginazione per grandi quantità di dati
/// - Filtri per categoria e stato
class DonatePage extends StatefulWidget {
  final ThemeManager themeManager;

  const DonatePage({
    super.key,
    required this.themeManager,
  });

  @override
  State<DonatePage> createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  List<Donation> _donations = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = AppDependencies.donationRepository;
      final items = await repo.getDonations();
      if (!mounted) return;
      setState(() {
        _donations = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Errore nel caricamento delle donazioni: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'da_visionare':
        return 'In attesa di verifica';
      case 'in_valutazione':
        return 'In valutazione';
      case 'in_ritiro':
        return 'Ritiro programmato';
      case 'concluso':
        return 'Completata';
      case 'rifiutato':
        return 'Rifiutata';
      default:
        return 'Sconosciuto';
    }
  }

  Color _getStatusColor(String status, bool isDark) {
    switch (status) {
      case 'da_visionare':
      case 'in_valutazione':
      case 'in_ritiro':
        return AppColors.primary(isDark);
      case 'concluso':
        return CupertinoColors.systemGreen;
      case 'rifiutato':
        return CupertinoColors.systemRed;
      default:
        return AppColors.textSecondary(isDark);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Oggi';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _createNewDonation() async {
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => DonateFormPage(
          themeManager: widget.themeManager,
        ),
      ),
    );

    if (result == true) {
      await _loadDonations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeManager,
      builder: (context, _) {
        final isDark = widget.themeManager.isDarkMode;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            middle: Text(
              'Donare un oggetto',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _errorMessage!,
                            style: AppTextStyles.body(isDark),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _donations.isEmpty
                    ? Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.gift,
                                      size: 64,
                                      color: AppColors.textSecondary(isDark).withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Nessuna donazione',
                                      style: AppTextStyles.title(isDark),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Le tue donazioni appariranno qui',
                                      style: AppTextStyles.bodySecondary(isDark),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Pulsante nuova donazione fisso in fondo
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _createNewDonation,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    CupertinoIcons.add_circled_solid,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Nuova donazione',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          // Lista scrollabile delle donazioni
                          Expanded(
                            child: CupertinoScrollbar(
                              child: CustomScrollView(
                                slivers: [
                                  CupertinoSliverRefreshControl(
                                    onRefresh: _loadDonations,
                                  ),
                                  SliverPadding(
                                    padding: const EdgeInsets.all(20),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          if (index == 0) {
                                            // Header
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Le tue donazioni',
                                                  style: AppTextStyles.title(isDark),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Visualizza la cronologia delle donazioni effettuate',
                                                  style: AppTextStyles.bodySecondary(isDark),
                                                ),
                                                const SizedBox(height: 20),
                                              ],
                                            );
                                          }
                                          
                                          final donation = _donations[index - 1];
                                          
                                          return _buildDonationCard(
                                            context: context,
                                            isDark: isDark,
                                            donation: donation,
                                          );
                                        },
                                        childCount: _donations.length + 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Pulsante nuova donazione fisso in fondo
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background(isDark),
                              border: Border(
                                top: BorderSide(
                                  color: AppColors.borderColor(isDark).withOpacity(0.1),
                                ),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: CupertinoButton.filled(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                borderRadius: BorderRadius.circular(12),
                                onPressed: _createNewDonation,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.add_circled_solid,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Nuova donazione',
                                      style: TextStyle(
                                        color: CupertinoColors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _buildDonationCard({
    required BuildContext context,
    required bool isDark,
    required Donation donation,
  }) {
    final itemName = donation.itemName;
    final category = donation.category ?? 'Altro';
    final date = donation.createdAt;
    final status = donation.status;
    final statusLabel = _getStatusLabel(status);
    final statusColor = _getStatusColor(status, isDark);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => DonationDetailPage(
              themeManager: widget.themeManager,
              donation: {
                'id': donation.id,
                'itemName': donation.itemName,
                'category': category,
                'description': donation.description,
                'date': donation.createdAt,
                'status': donation.status,
                'hasPhoto': donation.photoUrl != null,
                'rejectionReason': donation.rejectionReason,
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderColor(isDark).withOpacity(0.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
          children: [
            // Icona categoria o placeholder foto
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(category),
                size: 28,
                color: AppColors.primary(isDark),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    itemName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        size: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Badge stato
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Sport':
        return CupertinoIcons.sportscourt;
      case 'Libri':
        return CupertinoIcons.book;
      case 'Giochi':
        return CupertinoIcons.game_controller;
      default:
        return CupertinoIcons.gift;
    }
  }
}
