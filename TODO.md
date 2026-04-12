# MangroveGuardApp Tasks Complete ✓

1. ✅ Fixed loading screen flash after photo upload/Rescan (removed blocking Scaffold).
2. 🔄 NEW: Speed up photo inference (5s+ → <1s) with image resize optimization.

## Speedup Complete ✓
- [x] 1. Added _resizeImageForInference (PNG 512px max) → _processStillImage uses resized bytes (gallery).
- [x] 2. Updated _cropCapturedImageToFrame with resize after crop (live capture).
- Reduced timeout 8s → 4s.
- Expected: 5s+ → <1s inference.

Hot reload & test photo upload/capture timing.


