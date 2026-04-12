# MangroveGuardApp Camera Preview Fix - Task Progress

## Approved Plan Summary
1. Add permission_handler plugin & request camera permission before init
2. Improve diagnostics/logging/error UI in scanner_page.dart
3. Extend camera init retries + delays
4. Add permission hint in onboarding

## Steps (0/4 complete)

### ✅ 1. Update pubspec.yaml (add permission_handler)
- Add dependency ✓
- `flutter pub get` ✓

### ✅ 2. Edit scanner_page.dart
- Import permission_handler ✓
- Permission request in _scheduleCameraInit() ✓
- Enhanced error UI/logging ✓
- Safe dispose ✓
- Extended retries ✓

### ☐ 3. Edit onboarding_page.dart
- Add camera permission guidance text/card

### ☐ 4. Test & Verify
- flutter clean && flutter pub get
- Test first install on device: deny/grant permissions
- Check console logs, verify preview works

**Next Action**: Complete Step 1 (pubspec.yaml)

---

*Updated: $(date)*
