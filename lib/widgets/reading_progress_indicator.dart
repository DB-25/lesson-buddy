import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// A widget that displays reading progress as the user scrolls through content
class ReadingProgressIndicator extends StatefulWidget {
  final ScrollController scrollController;
  final double height;
  final Color? activeColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool showPercentage;

  const ReadingProgressIndicator({
    super.key,
    required this.scrollController,
    this.height = AppConstants.progressBarHeight,
    this.activeColor,
    this.backgroundColor,
    this.borderRadius,
    this.showPercentage = false,
  });

  @override
  State<ReadingProgressIndicator> createState() =>
      _ReadingProgressIndicatorState();
}

class _ReadingProgressIndicatorState extends State<ReadingProgressIndicator>
    with SingleTickerProviderStateMixin {
  double _progressValue = 0.0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: AppConstants.progressAnimationDuration,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    _animationController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!widget.scrollController.hasClients) return;

    final maxScrollExtent = widget.scrollController.position.maxScrollExtent;
    final currentPosition = widget.scrollController.offset;

    // Calculate progress (0.0 to 1.0)
    double newProgress = 0.0;
    if (maxScrollExtent > 0) {
      newProgress = (currentPosition / maxScrollExtent).clamp(0.0, 1.0);
    }

    if (newProgress != _progressValue) {
      setState(() {
        _progressValue = newProgress;
      });

      // Animate the progress change
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use theme colors instead of hardcoded constants
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final backgroundColor =
        widget.backgroundColor ?? theme.colorScheme.onSurface.withOpacity(0.1);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(widget.height / 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _progressValue,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                  minHeight: widget.height,
                ),
              ),
              if (widget.showPercentage) ...[
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '${(_progressValue * 100).round()}%',
                    key: ValueKey(_progressValue),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A more advanced scroll indicator that mimics a scrollbar
class ScrollIndicator extends StatefulWidget {
  final ScrollController scrollController;
  final double width;
  final Color? trackColor;
  final Color? thumbColor;
  final double thumbHeight;
  final BorderRadius? borderRadius;
  final ValueChanged<double>? onThumbRatioChanged;

  const ScrollIndicator({
    super.key,
    required this.scrollController,
    this.width = AppConstants.scrollIndicatorWidth,
    this.trackColor,
    this.thumbColor,
    this.thumbHeight = AppConstants.scrollIndicatorThumbHeight,
    this.borderRadius,
    this.onThumbRatioChanged,
  });

  @override
  State<ScrollIndicator> createState() => _ScrollIndicatorState();
}

class _ScrollIndicatorState extends State<ScrollIndicator> {
  double _thumbPosition = 0.0;
  double _thumbHeight = AppConstants.scrollIndicatorThumbHeight;
  double _availableHeight = 0.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrollListener);
    // Calculate initial thumb size after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollListener());
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    if (!widget.scrollController.hasClients || _availableHeight <= 0) return;

    final maxScrollExtent = widget.scrollController.position.maxScrollExtent;
    final currentPosition = widget.scrollController.offset;
    final viewportDimension = widget.scrollController.position.viewportDimension;

    if (maxScrollExtent > 0) {
      // Calculate thumb size based on content ratio
      final totalContentHeight = viewportDimension + maxScrollExtent;
      final contentRatio = viewportDimension / totalContentHeight;
      final calculatedThumbHeight = (_availableHeight * contentRatio).clamp(
        widget.thumbHeight, // Minimum thumb height
        _availableHeight * 0.9, // Maximum thumb height (90% of track)
      );

      // Calculate thumb position
      final progress = (currentPosition / maxScrollExtent).clamp(0.0, 1.0);
      final maxThumbPosition = _availableHeight - calculatedThumbHeight;
      final newThumbPosition = progress * maxThumbPosition;

      setState(() {
        _thumbHeight = calculatedThumbHeight;
        _thumbPosition = newThumbPosition;
      });

      // Notify parent about thumb ratio for visibility decisions
      if (widget.onThumbRatioChanged != null && _availableHeight > 0) {
        final thumbRatio = calculatedThumbHeight / _availableHeight;
        widget.onThumbRatioChanged!(thumbRatio);
      }
    } else {
      // No scrolling needed - thumb fills most of the track
      setState(() {
        _thumbHeight = _availableHeight * 0.9;
        _thumbPosition = 0.0;
      });

      // Notify parent about thumb ratio
      if (widget.onThumbRatioChanged != null && _availableHeight > 0) {
        final thumbRatio = (_availableHeight * 0.9) / _availableHeight;
        widget.onThumbRatioChanged!(thumbRatio);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use theme colors instead of hardcoded constants
    final trackColor =
        widget.trackColor ?? theme.colorScheme.onSurface.withOpacity(0.1);
    final thumbColor = widget.thumbColor ?? theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final newAvailableHeight = constraints.maxHeight;
        
        // Update available height and recalculate if it changed
        if (_availableHeight != newAvailableHeight) {
          _availableHeight = newAvailableHeight;
          // Use post frame callback to avoid calling setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollListener());
        }

        return Container(
          width: widget.width,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(widget.width / 2),
          ),
          child: Stack(
            children: [
              Positioned(
                top: _thumbPosition,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: AppConstants.progressAnimationDuration,
                  height: _thumbHeight,
                  decoration: BoxDecoration(
                    color: thumbColor,
                    borderRadius: BorderRadius.circular(widget.width / 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
