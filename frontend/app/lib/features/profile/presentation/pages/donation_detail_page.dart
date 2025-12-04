import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

/// Pagina di dettaglio di una singola donazione
/// 
/// Mostra tutti i dettagli della donazione:
/// - Nome oggetto
/// - Categoria
/// - Descrizione
/// - Data di donazione
/// - Stato attuale
/// - Se rifiutata: motivo di rifiuto o messaggio generico
/// - Se confermata: istruzioni per la consegna
class DonationDetailPage extends StatelessWidget {
  final ThemeManager themeManager;
  final Map<String, dynamic> donation;

  const DonationDetailPage({
    super.key,
    required this.themeManager,
    required this.donation,
  });

  String _getStatusLabel(String status) {
    switch (status) {
      case 'in_attesa':
        return 'In attesa di verifica';
      case 'confermata':
        return 'Confermata';
      case 'consegnata':
        return 'Consegnata';
      case 'rifiutata':
        return 'Rifiutata';
      default:
        return 'Sconosciuto';
    }
  }

  Color _getStatusColor(String status, bool isDark) {
    switch (status) {
      case 'in_attesa':
        return AppColors.primary(isDark);
      case 'confermata':
        return CupertinoColors.systemGreen;
      case 'consegnata':
        return CupertinoColors.systemPurple;
      case 'rifiutata':
        return CupertinoColors.systemRed;
      default:
        return AppColors.textSecondary(isDark);
    }
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, _) {
        final isDark = themeManager.isDarkMode;
        final itemName = donation['itemName'] as String;
        final category = donation['category'] as String;
        final description = donation['description'] as String;
        final date = donation['date'] as DateTime;
        final status = donation['status'] as String;
        final statusLabel = _getStatusLabel(status);
        final statusColor = _getStatusColor(status, isDark);
        final rejectionReason = donation['rejectionReason'] as String?;
        final hasPhoto = donation['hasPhoto'] as bool;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            middle: Text(
              'Dettaglio donazione',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge stato
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Nome oggetto
                  Text(
                    'Oggetto',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      itemName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(isDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Categoria
                  Text(
                    'Categoria',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          size: 20,
                          color: AppColors.primary(isDark),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Descrizione
                  Text(
                    'Descrizione',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.text(isDark),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Data
                  Text(
                    'Data donazione',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 18,
                          color: AppColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Foto (se presente)
                  if (hasPhoto) ...[
                    Text(
                      'Foto allegata',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.borderColor(isDark).withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.photo,
                            size: 24,
                            color: AppColors.primary(isDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Foto disponibile',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.text(isDark),
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Messaggio in base allo stato
                  if (status == 'rifiutata') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.systemRed.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 20,
                                color: CupertinoColors.systemRed,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Donazione rifiutata',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.systemRed,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                            Text(
                              'Motivo:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text(isDark),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rejectionReason,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.text(isDark),
                                height: 1.5,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Ci dispiace, la tua donazione non è stata accettata. L\'oggetto potrebbe non rispettare i criteri di qualità richiesti o potrebbe non essere idoneo per la donazione.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.text(isDark),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (status == 'confermata') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.systemGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                size: 20,
                                color: CupertinoColors.systemGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Donazione confermata',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.systemGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'La tua donazione è stata approvata! Per completare la procedura, consegna l\'oggetto presso:',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.text(isDark),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface(isDark),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.location_solid,
                                      size: 16,
                                      color: AppColors.primary(isDark),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Comune di Trento',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Via Manci, 2\n38122 Trento',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Orari: Lun-Ven 9:00-17:00',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Porta con te un documento di identità e menziona che hai una donazione da consegnare tramite l\'app NULL.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(isDark),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (status == 'consegnata') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.systemPurple.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                size: 20,
                                color: CupertinoColors.systemPurple,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Donazione consegnata',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.systemPurple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Grazie per la tua donazione! L\'oggetto è stato consegnato con successo al Comune di Trento e sarà utilizzato per aiutare la comunità.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.text(isDark),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Il tuo contributo è molto apprezzato e aiuterà altre persone nella comunità.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(isDark),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (status == 'in_attesa') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary(isDark).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary(isDark).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.clock,
                                size: 20,
                                color: AppColors.primary(isDark),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'In attesa di verifica',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary(isDark),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'La tua donazione è in attesa di essere verificata dal nostro team. Riceverai una notifica non appena sarà esaminata.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.text(isDark),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

