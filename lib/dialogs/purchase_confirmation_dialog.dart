import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils.dart';

class PurchaseConfirmationDialog extends StatefulWidget {
  final ProductDetails product;
  final InAppPurchase iap;

  const PurchaseConfirmationDialog({
    super.key,
    required this.product,
    required this.iap,
  });

  @override
  State<PurchaseConfirmationDialog> createState() =>
      _PurchaseConfirmationDialogState();
}

class _PurchaseConfirmationDialogState
    extends State<PurchaseConfirmationDialog> {
  bool _isPurchasing = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        if (mounted) {
          setState(() {
            _isPurchasing = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    // 다이얼로그가 닫힐 때 상태를 확실히 리셋
    _isPurchasing = false;
    _subscription?.cancel();
    super.dispose();
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    print(
      '[PurchaseDialog] _handlePurchaseUpdates called with ${purchaseDetailsList.length} items',
    );

    final matchingPurchase =
        purchaseDetailsList
            .where((p) => p.productID == widget.product.id)
            .firstOrNull;

    if (matchingPurchase == null) {
      print('[PurchaseDialog] No matching purchase found');
      return;
    }

    print(
      '[PurchaseDialog] Matching purchase found: ${matchingPurchase.productID}, status: ${matchingPurchase.status}',
    );

    // 다이얼로그가 이미 닫혔다면 처리하지 않음
    if (!mounted) {
      print('[PurchaseDialog] Dialog not mounted, skipping update');
      return;
    }

    setState(() {
      switch (matchingPurchase.status) {
        case PurchaseStatus.pending:
          print('[PurchaseDialog] Purchase pending');
          _isPurchasing = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          print('[PurchaseDialog] Purchase successful');
          _isPurchasing = false;
          if (mounted) {
            Navigator.of(context).pop();
          }
          break;
        case PurchaseStatus.error:
          print(
            '[PurchaseDialog] Purchase error: ${matchingPurchase.error?.message}',
          );
          _isPurchasing = false;
          break;
        case PurchaseStatus.canceled:
          print('[PurchaseDialog] Purchase canceled');
          // 취소 시 스피너 중지
          _isPurchasing = false;
          break;
      }
    });

    if (matchingPurchase.pendingCompletePurchase) {
      widget.iap.completePurchase(matchingPurchase);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    // 앱 자체의 개인정보 처리 방침 페이지
    final url = Uri.parse(
      'https://smartcompany.github.io/USDTSignal/privacy.html',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTermsOfService() async {
    // 앱 자체의 이용약관 페이지
    final url = Uri.parse(
      'https://smartcompany.github.io/USDTSignal/terms.html',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _onCancelPressed() {
    // 취소 시 스피너를 즉시 중지
    if (mounted) {
      setState(() {
        _isPurchasing = false;
      });
      Navigator.of(context).pop();
    }
  }

  Future<void> _onPurchasePressed() async {
    if (_isPurchasing) return; // 이미 구매 중이면 무시

    setState(() {
      _isPurchasing = true;
    });

    try {
      final purchaseParam = PurchaseParam(productDetails: widget.product);
      final result = await widget.iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      print('Purchase result: $result');

      // 사용자가 결제 UI를 닫아 구매를 진행하지 않은 경우,
      // buyNonConsumable은 반환되지만 스트림 업데이트가 오지 않을 수 있다.
      // 스트림 업데이트가 올 수 있으므로 짧은 딜레이 후 상태를 확인한다.
      await Future.delayed(const Duration(milliseconds: 300));

      // 여전히 purchasing 상태이고 업데이트가 오지 않았다면 취소된 것으로 간주
      if (mounted && _isPurchasing) {
        print(
          '[PurchaseDialog] No purchase update received, assuming canceled',
        );
        setState(() {
          _isPurchasing = false;
        });
      }
    } catch (e) {
      print('Purchase failed to start: $e');
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n(context).loadingFail)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(
            Icons.remove_circle_outline,
            color: Colors.deepPurple,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n(context).removeAdsCta,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 가격 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Center(
                child: Text(
                  widget.product.price,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 설명
            Text(
              l10n(context).removeAdsDescription,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // 개인정보 처리 방침 및 이용약관 링크
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _isPurchasing ? null : _openPrivacyPolicy,
                  child: Text(
                    l10n(context).privacyPolicy,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Text(' | ', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: _isPurchasing ? null : _openTermsOfService,
                  child: Text(
                    l10n(context).termsOfService,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _onCancelPressed,
          child: Text(
            l10n(context).cancel,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: _isPurchasing ? null : _onPurchasePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
              _isPurchasing
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(
                    l10n(context).purchaseButton,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ],
    );
  }
}
