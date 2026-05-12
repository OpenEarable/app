import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/common/app_section_card.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detailed screen for firmware image slot metadata exposed by a wearable.
class FotaSlotsPage extends StatefulWidget {
  final Wearable device;

  const FotaSlotsPage({
    super.key,
    required this.device,
  });

  @override
  State<FotaSlotsPage> createState() => _FotaSlotsPageState();
}

class _FotaSlotsPageState extends State<FotaSlotsPage> {
  static final Uri _mcumgrWebUri =
      Uri.parse('https://boogie.github.io/mcumgr-web/');

  late Future<List<FirmwareSlotInfo>> _slotFuture;
  String? _erasingSlotKey;

  @override
  void initState() {
    super.initState();
    _slotFuture = _loadSlots();
  }

  /// Reads the current slot snapshot from the device capability.
  Future<List<FirmwareSlotInfo>> _loadSlots() async {
    if (!widget.device.hasCapability<FotaSlotInfoCapability>()) {
      return const [];
    }

    final capability =
        widget.device.requireCapability<FotaSlotInfoCapability>();
    final slots = await capability.readFirmwareSlots();
    final sortedSlots = [...slots]..sort((a, b) {
        final imageCompare = a.image.compareTo(b.image);
        if (imageCompare != 0) {
          return imageCompare;
        }
        return a.slot.compareTo(b.slot);
      });
    return sortedSlots;
  }

  /// Triggers a fresh device read and rebuilds the page state.
  Future<void> _refreshSlots() async {
    final future = _loadSlots();
    setState(() {
      _slotFuture = future;
    });
    await future;
  }

  /// Confirms and erases the secondary firmware slot represented by [slot].
  Future<void> _eraseFirmwareSlot(FirmwareSlotInfo slot) async {
    if (!_canEraseSlot(slot) ||
        _erasingSlotKey != null ||
        !widget.device.hasCapability<FotaSlotInfoCapability>()) {
      return;
    }

    final confirmed = await _confirmEraseSlot(slot);
    if (!confirmed || !mounted) {
      return;
    }

    final slotKey = _slotKey(slot);
    setState(() {
      _erasingSlotKey = slotKey;
    });

    try {
      final capability =
          widget.device.requireCapability<FotaSlotInfoCapability>();
      await capability.eraseFirmwareSlot(channel: _eraseChannelFor(slot));

      if (!mounted) {
        return;
      }

      AppToast.show(
        context,
        message: 'Firmware slot ${slot.slot} erased.',
        type: AppToastType.success,
        icon: Icons.delete_sweep_rounded,
      );

      await _refreshSlots();
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.show(
        context,
        message: 'Could not erase firmware slot ${slot.slot}.',
        type: AppToastType.error,
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _erasingSlotKey = null;
        });
      }
    }
  }

  /// Asks the user to confirm the destructive slot erase operation.
  Future<bool> _confirmEraseSlot(FirmwareSlotInfo slot) async {
    final result = await showPlatformDialog<bool>(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Erase Firmware Slot?'),
        content: Text(
          'This erases image ${slot.image}, slot ${slot.slot} from the '
          'device. Use this only to recover from broken or stuck firmware '
          'updates.',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PlatformDialogAction(
            cupertino: (_, __) => CupertinoDialogActionData(
              isDestructiveAction: true,
            ),
            child: const Text('Erase'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Returns whether the firmware backend should accept erasing [slot].
  bool _canEraseSlot(FirmwareSlotInfo slot) {
    return slot.slot > 0 && !slot.active;
  }

  /// Returns the raw mcumgr erase channel for the slot.
  int? _eraseChannelFor(FirmwareSlotInfo slot) {
    return slot.image == 0 ? null : slot.image;
  }

  /// Opens the external mcumgr web UI that can help erase image slots.
  Future<void> _openMcumgrWeb() async {
    final opened = await launchUrl(
      _mcumgrWebUri,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !mounted) {
      return;
    }

    AppToast.show(
      context,
      message: 'Could not open mcumgr web.',
      type: AppToastType.error,
      icon: Icons.link_off_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Image Slots'),
      ),
      body: FutureBuilder<List<FirmwareSlotInfo>>(
        future: _slotFuture,
        builder: (context, snapshot) {
          final slots = snapshot.data ?? const <FirmwareSlotInfo>[];

          return RefreshIndicator(
            onRefresh: _refreshSlots,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
              children: [
                _SlotsOverviewCard(
                  device: widget.device,
                  slots: slots,
                  isLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                ),
                const SizedBox(height: SensorPageSpacing.sectionGap),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const _SlotsLoadingCard()
                else if (snapshot.hasError)
                  _SlotsErrorCard(onRetry: _refreshSlots)
                else if (slots.isEmpty)
                  const _SlotsEmptyCard()
                else
                  ..._buildImageSections(context, slots),
                const SizedBox(height: SensorPageSpacing.sectionGap),
                _SlotRecoveryCard(onOpenTool: _openMcumgrWeb),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds grouped sections per firmware image index.
  List<Widget> _buildImageSections(
    BuildContext context,
    List<FirmwareSlotInfo> slots,
  ) {
    final widgets = <Widget>[];
    final slotsByImage = <int, List<FirmwareSlotInfo>>{};

    for (final slot in slots) {
      slotsByImage
          .putIfAbsent(slot.image, () => <FirmwareSlotInfo>[])
          .add(slot);
    }

    final imageIds = slotsByImage.keys.toList()..sort();
    for (var index = 0; index < imageIds.length; index++) {
      final imageId = imageIds[index];
      final imageSlots = slotsByImage[imageId]!;
      widgets.add(
        AppSectionCard(
          title: 'Image $imageId',
          subtitle:
              '${imageSlots.length} reported slot${imageSlots.length == 1 ? '' : 's'}.',
          child: Column(
            children: [
              for (var slotIndex = 0;
                  slotIndex < imageSlots.length;
                  slotIndex++) ...[
                _SlotTile(
                  slot: imageSlots[slotIndex],
                  canErase: _canEraseSlot(imageSlots[slotIndex]),
                  isErasing: _erasingSlotKey == _slotKey(imageSlots[slotIndex]),
                  isEraseBusy: _erasingSlotKey != null,
                  onErase: () => _eraseFirmwareSlot(imageSlots[slotIndex]),
                ),
                if (slotIndex < imageSlots.length - 1)
                  const SizedBox(height: SensorPageSpacing.sectionGap),
              ],
            ],
          ),
        ),
      );

      if (index < imageIds.length - 1) {
        widgets.add(const SizedBox(height: SensorPageSpacing.sectionGap));
      }
    }

    return widgets;
  }
}

/// Creates a stable UI key for state associated with one firmware slot.
String _slotKey(FirmwareSlotInfo slot) => '${slot.image}:${slot.slot}';

/// Recovery card that explains the in-app slot erasing action and fallback.
class _SlotRecoveryCard extends StatelessWidget {
  final Future<void> Function() onOpenTool;

  const _SlotRecoveryCard({
    required this.onOpenTool,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const warningBackground = Color(0xFFFFECEC);
    const warningForeground = Color(0xFF8A1C1C);

    return AppSectionCard(
      title: 'Recovery',
      subtitle: 'Use this if firmware update stops working correctly.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: warningBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: warningForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Erasing the slots resets the FOTA state and may help recover devices when FOTA is stuck or not working correctly.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: warningForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use the erase action on an inactive secondary slot above to clear the image table and let you start the firmware update flow again.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'If in-app erasing fails, mcumgr web can be used as a fallback. It may be necessary to remove the wearable from the app and settings in order to discover it there.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenTool,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open mcumgr web'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary card shown above the detailed slot list.
class _SlotsOverviewCard extends StatelessWidget {
  final Wearable device;
  final List<FirmwareSlotInfo> slots;
  final bool isLoading;

  const _SlotsOverviewCard({
    required this.device,
    required this.slots,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final activeSlots = slots.where((slot) => slot.active).length;
    final pendingSlots = slots.where((slot) => slot.pending).length;
    final confirmedSlots = slots.where((slot) => slot.confirmed).length;

    return AppSectionCard(
      title: 'Firmware Slot State',
      subtitle: 'Live MCUboot image table details reported by the device.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatWearableDisplayName(device.name),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                label: '${slots.length} slots',
                tone: _SummaryChipTone.neutral,
              ),
              _SummaryChip(
                label: '$activeSlots active',
                tone: _SummaryChipTone.good,
              ),
              _SummaryChip(
                label: '$pendingSlots pending',
                tone: pendingSlots > 0
                    ? _SummaryChipTone.warning
                    : _SummaryChipTone.neutral,
              ),
              _SummaryChip(
                label: '$confirmedSlots confirmed',
                tone: _SummaryChipTone.info,
              ),
              if (isLoading)
                const _SummaryChip(
                  label: 'Refreshing',
                  tone: _SummaryChipTone.neutral,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loading state card for slot reads.
class _SlotsLoadingCard extends StatelessWidget {
  const _SlotsLoadingCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppSectionCard(
      title: 'Reading Slots',
      subtitle: 'Fetching the current firmware image table from the wearable.',
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This usually finishes within a few seconds.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state card shown when the device reports no image slots.
class _SlotsEmptyCard extends StatelessWidget {
  const _SlotsEmptyCard();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'No Slot Data',
      subtitle: 'The device did not return any firmware image slot entries.',
      child: Text(
        'Try pulling to refresh after reconnecting if you expected slot data to be available.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// Error state card shown when the slot read fails.
class _SlotsErrorCard extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _SlotsErrorCard({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppSectionCard(
      title: 'Could Not Read Slots',
      subtitle:
          'The wearable rejected the request or the connection was interrupted.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Make sure the device stays connected, then try again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Visual card for one reported firmware slot.
class _SlotTile extends StatelessWidget {
  final FirmwareSlotInfo slot;
  final bool canErase;
  final bool isErasing;
  final bool isEraseBusy;
  final VoidCallback onErase;

  const _SlotTile({
    required this.slot,
    required this.canErase,
    required this.isErasing,
    required this.isEraseBusy,
    required this.onErase,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Slot ${slot.slot}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                slot.version?.trim().isNotEmpty == true
                    ? slot.version!.trim()
                    : 'Version unknown',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (slot.active)
                const _StatusChip(label: 'Active', tone: _StatusChipTone.good),
              if (slot.confirmed)
                const _StatusChip(
                  label: 'Confirmed',
                  tone: _StatusChipTone.info,
                ),
              if (slot.pending)
                const _StatusChip(
                  label: 'Pending',
                  tone: _StatusChipTone.warning,
                ),
              if (slot.permanent)
                const _StatusChip(
                  label: 'Permanent',
                  tone: _StatusChipTone.info,
                ),
              _StatusChip(
                label: slot.bootable ? 'Bootable' : 'Not Bootable',
                tone: slot.bootable
                    ? _StatusChipTone.good
                    : _StatusChipTone.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SlotMetadataRow(label: 'Image', value: '${slot.image}'),
          const SizedBox(height: 8),
          _SlotMetadataRow(label: 'Hash', value: _formatHash(slot.hashString)),
          const SizedBox(height: 12),
          _SlotEraseAction(
            canErase: canErase,
            isErasing: isErasing,
            isEraseBusy: isEraseBusy,
            onErase: onErase,
          ),
        ],
      ),
    );
  }

  /// Shortens the reported hash for dense mobile presentation.
  String _formatHash(String hash) {
    if (hash.length <= 20) {
      return hash;
    }

    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 8)}';
  }
}

/// Destructive action surface for erasing an eligible firmware slot.
class _SlotEraseAction extends StatelessWidget {
  final bool canErase;
  final bool isErasing;
  final bool isEraseBusy;
  final VoidCallback onErase;

  const _SlotEraseAction({
    required this.canErase,
    required this.isErasing,
    required this.isEraseBusy,
    required this.onErase,
  });

  @override
  Widget build(BuildContext context) {
    if (!canErase) {
      return _SlotEraseNotice(
        icon: Icons.lock_outline_rounded,
        text:
            'This slot is protected because it is primary or active.',
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isEraseBusy ? null : onErase,
        icon: isErasing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_outline_rounded, size: 18),
        label: Text(isErasing ? 'Erasing slot' : 'Erase slot'),
      ),
    );
  }
}

/// Compact explanation for slots that cannot be erased safely.
class _SlotEraseNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SlotEraseNotice({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

/// Compact label-value row for slot metadata.
class _SlotMetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _SlotMetadataRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

enum _StatusChipTone { good, info, warning, muted }

/// Small status pill used on each slot card.
class _StatusChip extends StatelessWidget {
  final String label;
  final _StatusChipTone tone;

  const _StatusChip({
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(context, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.$2,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

enum _SummaryChipTone { neutral, good, info, warning }

/// Summary pill used in the page overview card.
class _SummaryChip extends StatelessWidget {
  final String label;
  final _SummaryChipTone tone;

  const _SummaryChip({
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final mappedTone = switch (tone) {
      _SummaryChipTone.good => _StatusChipTone.good,
      _SummaryChipTone.info => _StatusChipTone.info,
      _SummaryChipTone.warning => _StatusChipTone.warning,
      _SummaryChipTone.neutral => _StatusChipTone.muted,
    };
    final colors = _colorsFor(context, mappedTone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.$2,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Resolves chip foreground and background colors for the current theme.
(Color, Color) _colorsFor(BuildContext context, _StatusChipTone tone) {
  final colorScheme = Theme.of(context).colorScheme;

  return switch (tone) {
    _StatusChipTone.good => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
    _StatusChipTone.info => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
    _StatusChipTone.warning => (
        const Color(0xFFFFE7C2),
        const Color(0xFF7A4B00),
      ),
    _StatusChipTone.muted => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
  };
}
