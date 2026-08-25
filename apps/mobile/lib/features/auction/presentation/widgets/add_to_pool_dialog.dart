import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../players/application/players_providers.dart';
import '../../../players/data/models/player.dart';
import '../../data/auction_repository.dart';

/// Modal for bulk-adding org players to a session's lot pool, matching
/// `AddToPoolDto` in apps/backend/src/modules/auction/dto/add-to-pool.dto.ts
/// (each entry needs a `playerId`, `basePrice`, and `lotOrder`).
///
/// Players already in the pool are excluded from the picker (the backend
/// rejects duplicates with a 409 anyway — see `AuctionService.addToPool` —
/// but filtering client-side avoids a confusing round-trip). Lot order is
/// assigned automatically in selection order, continuing on from
/// [existingPoolSize] — M1 keeps this simple with no manual reordering UI.
Future<List<AddPoolEntryInput>?> showAddToPoolDialog(
  BuildContext context, {
  required String organizationId,
  required Set<String> excludedPlayerIds,
  required int existingPoolSize,
}) {
  return showDialog<List<AddPoolEntryInput>>(
    context: context,
    builder: (context) => _AddToPoolDialog(
      organizationId: organizationId,
      excludedPlayerIds: excludedPlayerIds,
      existingPoolSize: existingPoolSize,
    ),
  );
}

class _AddToPoolDialog extends ConsumerStatefulWidget {
  const _AddToPoolDialog({
    required this.organizationId,
    required this.excludedPlayerIds,
    required this.existingPoolSize,
  });

  final String organizationId;
  final Set<String> excludedPlayerIds;
  final int existingPoolSize;

  @override
  ConsumerState<_AddToPoolDialog> createState() => _AddToPoolDialogState();
}

class _AddToPoolDialogState extends ConsumerState<_AddToPoolDialog> {
  /// Selection order determines lot order, so this is a `List`, not a `Set`.
  final List<String> _selectedOrder = [];
  final Map<String, TextEditingController> _basePriceControllers = {};
  String? _validationError;

  @override
  void dispose() {
    for (final controller in _basePriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle(Player player) {
    setState(() {
      if (_selectedOrder.contains(player.id)) {
        _selectedOrder.remove(player.id);
        _basePriceControllers.remove(player.id)?.dispose();
      } else {
        _selectedOrder.add(player.id);
        _basePriceControllers[player.id] = TextEditingController(text: player.basePrice ?? '');
      }
    });
  }

  void _submit() {
    if (_selectedOrder.isEmpty) {
      setState(() => _validationError = 'Select at least one player');
      return;
    }
    final entries = <AddPoolEntryInput>[];
    for (var i = 0; i < _selectedOrder.length; i++) {
      final playerId = _selectedOrder[i];
      final priceText = _basePriceControllers[playerId]!.text.trim();
      final basePrice = num.tryParse(priceText);
      if (basePrice == null || basePrice < 0) {
        setState(() => _validationError = 'Enter a valid base price for every selected player');
        return;
      }
      entries.add(AddPoolEntryInput(
        playerId: playerId,
        basePrice: basePrice,
        lotOrder: widget.existingPoolSize + i + 1,
      ));
    }
    Navigator.of(context).pop(entries);
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersListProvider);

    return AlertDialog(
      title: const Text('Add players to pool'),
      content: SizedBox(
        width: 420,
        height: 480,
        child: playersAsync.when(
          data: (players) {
            final eligible =
                players.where((p) => !widget.excludedPlayerIds.contains(p.id)).toList();
            if (eligible.isEmpty) {
              return const Center(child: Text('All org players are already in this pool.'));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_validationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _validationError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: eligible.length,
                    itemBuilder: (context, index) {
                      final player = eligible[index];
                      final selected = _selectedOrder.contains(player.id);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CheckboxListTile(
                            value: selected,
                            onChanged: (_) => _toggle(player),
                            title: Text(player.fullName),
                            subtitle: Text(player.role.label),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          if (selected)
                            Padding(
                              padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
                              child: TextField(
                                controller: _basePriceControllers[player.id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Base price',
                                  isDense: true,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(error is ApiException ? error.message : 'Failed to load players'),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text('Add (${_selectedOrder.length})')),
      ],
    );
  }
}
