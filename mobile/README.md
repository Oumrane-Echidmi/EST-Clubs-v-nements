# EST Clubs & Événements — Mobile (Flutter)

Student / club-admin / super-admin app. UI follows the Stitch designs in `../docs/design/`.
Status and to-do list: `../docs/TASKS.md` (read it first).

## Run it
```bash
# Flutter lives at C:\Users\PC\flutter — add its bin folder to PATH
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api   # URL is optional
```
Android emulator reaches your PC at `10.0.2.2`. The backend must be running for login to work.

## Folder map (feature-first)
```
lib/
  main.dart                 app entry, theme + router
  core/                     code shared by every feature
    config/api_config.dart  backend URL (one place)
    network/                Dio client + auth_interceptor (adds token, refreshes on 401)
    storage/                secure token storage
    errors/                 backend error code -> French message
    router/app_router.dart  routes + role-based redirects
    theme/app_theme.dart    colors/spacing/radius from Stitch
    widgets/                Loading / Empty / Error views
  features/<name>/
    data/                   talks to the API (repository)
    domain/                 plain models & rules
    presentation/           screens + Riverpod providers
```

## Rules of thumb
- The **backend decides** permissions, seat counts and registration state. The app only displays them.
- Screens never call Dio directly: screen -> provider -> repository -> Dio.
- Errors from the API arrive as `AppException` (already translated). Show `e.message`.
- Disable buttons while a request runs (see `_AuthFormPage`) to avoid double submits.
- Use `EdgeInsetsDirectional` (not `EdgeInsets.only(left:)`) so Arabic/RTL works later.
- Tests use fakes only inside `test/`. Look at `test/foundation_test.dart` for examples.

## Adding a feature (example: clubs list)
1. Model + repository in `features/clubs/{domain,data}`.
2. A Riverpod provider that loads the list (`AsyncNotifier`).
3. Screen using `LoadingView` / `ErrorView` / `EmptyState` + the data.
4. Register the route in `core/router/app_router.dart`.
5. Add a test, run `flutter analyze && flutter test`, update `../docs/TASKS.md`.
