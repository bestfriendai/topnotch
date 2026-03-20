# Sign in with Apple Setup Guide - What2WatchAI

## Overview

This guide covers the complete setup for Sign in with Apple for the What2WatchAI app, including Apple Developer Portal configuration, Supabase integration, and iOS implementation.

---

## Quick Reference

| Field | Value |
|-------|-------|
| Bundle ID | `com.what2watchai.app` |
| Services ID | `com.what2watchai.app.signin` |
| Team ID | `CY89UC5Z6Z` |
| Key ID | `PRKWBSZ4FZ` |

---

## Part 1: Apple Developer Portal Setup

### 1.1 Enable Sign in with Apple for App ID

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)
2. Click on `com.what2watchai.app`
3. Scroll to "Capabilities"
4. Enable **Sign in with Apple**
5. Select **"Enable as a primary App ID"**
6. Click Save

### 1.2 Create Services ID (for Web/OAuth)

This is required for Supabase OAuth flow:

1. Go to Identifiers > Click "+"
2. Select **Services IDs** > Continue
3. Fill in:
   - Description: `What2WatchAI Sign In`
   - Identifier: `com.what2watchai.app.signin`
4. Click Register
5. Click on the newly created Services ID
6. Enable **Sign in with Apple**
7. Click Configure:

**Configuration:**
```
Primary App ID: com.what2watchai.app
Domains and Subdomains:
  - what2watchai.com
  - [YOUR_SUPABASE_REF].supabase.co

Return URLs:
  - https://[YOUR_SUPABASE_REF].supabase.co/auth/v1/callback
  - https://what2watchai.com/auth/callback
```

### 1.3 Create/Verify Sign in with Apple Key

The key already exists in AppSetUpKit folder. Verify it's registered:

1. Go to Keys section
2. Look for key with ID: `PRKWBSZ4FZ`
3. Ensure "Sign in with Apple" is enabled
4. Associated App IDs should include `com.what2watchai.app`

If key needs to be re-registered:
1. Create new key
2. Enable "Sign in with Apple"
3. Select `com.what2watchai.app` as primary
4. Download .p8 file (one-time only!)

---

## Part 2: Xcode/iOS Setup

### 2.1 Entitlements (Already Configured)

The entitlements file already includes Sign in with Apple:

**MovieTrailer.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

### 2.2 Implementation Code

**AppleSignInManager.swift:**
```swift
import AuthenticationServices
import CryptoKit

@MainActor
class AppleSignInManager: NSObject, ObservableObject {
    @Published var isSigningIn = false
    @Published var error: Error?
    
    private var currentNonce: String?
    
    func signIn() async throws -> ASAuthorization {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = SignInDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
    
    // MARK: - Nonce Generation
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}

// MARK: - Delegate

private class SignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}
```

### 2.3 SwiftUI Button

**AppleSignInButton.swift:**
```swift
import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    @Environment(\.colorScheme) var colorScheme
    let onComplete: (Result<ASAuthorization, Error>) -> Void
    
    var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: onComplete
        )
        .signInWithAppleButtonStyle(
            colorScheme == .dark ? .white : .black
        )
        .frame(height: 50)
        .cornerRadius(12)
    }
}
```

---

## Part 3: Supabase Integration

### 3.1 Configure Supabase Auth Provider

**Via Dashboard:**
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to Authentication > Providers
4. Enable Apple
5. Fill in:
   - Services ID: `com.what2watchai.app.signin`
   - Secret Key: Contents of `.p8` file (see below)

**Via Management API:**
```bash
# Run from AppSetUpKit directory
./scripts/supabase-auth-setup.sh
```

### 3.2 Apple Secret Key Format

The secret key for Supabase is the contents of the `.p8` file:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgCp8i2EwjWU3jjjsW
In284q6z3IODnlpep79vdNO1fHSgCgYIKoZIzj0DAQehRANCAAR9KrZ5WGQiC2gQ
KrbxEqn0j/B51yZm6p07NxNZqXbr4uadFhDLB5eNno9aNw24zhZ4lHwj+lzK1mUB
rCppsGi3
-----END PRIVATE KEY-----
```

### 3.3 Supabase Swift Implementation

**SupabaseAppleAuth.swift:**
```swift
import Supabase
import AuthenticationServices

class SupabaseAuthManager {
    static let shared = SupabaseAuthManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://YOUR_PROJECT_REF.supabase.co")!,
            supabaseKey: "YOUR_ANON_KEY"
        )
    }
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> Session {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidToken
        }
        
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: tokenString
            )
        )
        
        // Update user profile with name if available
        if let fullName = credential.fullName {
            let displayName = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            if !displayName.isEmpty {
                try await client.auth.update(user: .init(
                    data: ["full_name": .string(displayName)]
                ))
            }
        }
        
        return session
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
}

enum AuthError: Error {
    case invalidToken
    case noUser
}
```

---

## Part 4: Firebase Integration (Alternative)

If using Firebase Auth instead of/alongside Supabase:

### 4.1 Firebase Console Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: `movietrailer-1767069717`
3. Go to Authentication > Sign-in method
4. Enable Apple
5. Fill in:
   - Services ID: `com.what2watchai.app.signin`
   - Apple Team ID: `CY89UC5Z6Z`
   - Key ID: `PRKWBSZ4FZ`
   - Private Key: Contents of `.p8` file

### 4.2 Firebase Swift Implementation

**FirebaseAppleAuth.swift:**
```swift
import FirebaseAuth
import AuthenticationServices
import CryptoKit

class FirebaseAuthManager {
    static let shared = FirebaseAuthManager()
    
    private var currentNonce: String?
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AuthDataResult {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8),
              let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        
        return try await Auth.auth().signIn(with: credential)
    }
    
    func prepareSignIn() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }
    
    // Nonce helpers (same as above)
    private func randomNonceString(length: Int = 32) -> String { /* ... */ }
    private func sha256(_ input: String) -> String { /* ... */ }
}

enum AuthError: Error {
    case invalidCredential
}
```

---

## Part 5: Testing

### 5.1 Simulator Testing

Sign in with Apple works in simulator with these limitations:
- Use your real Apple ID
- Name/email may show as private relay

### 5.2 Device Testing

1. Ensure you're signed into iCloud on device
2. Run app from Xcode
3. Tap "Sign in with Apple"
4. Authenticate with Face ID/Touch ID

### 5.3 Test Accounts

For App Store review, provide:
- Demo account (if login required)
- Note that Sign in with Apple requires real Apple ID

---

## Part 6: Troubleshooting

### Common Errors

**"Invalid client_id"**
- Verify Services ID is correctly registered
- Check bundle ID matches primary App ID

**"Unable to process request"**
- Verify .p8 key is correctly configured
- Check key hasn't been revoked
- Ensure key is associated with correct App ID

**"Nonce mismatch"**
- Ensure you're using the same nonce for request and verification
- Don't reuse nonces between sign-in attempts

**"Missing entitlements"**
- Verify entitlements file is included in target
- Check signing settings in Xcode
- Rebuild after adding entitlements

### Debug Logging

Add this to debug sign-in issues:
```swift
func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    if let error = error as? ASAuthorizationError {
        switch error.code {
        case .canceled:
            print("User canceled sign in")
        case .failed:
            print("Sign in failed")
        case .invalidResponse:
            print("Invalid response")
        case .notHandled:
            print("Not handled")
        case .unknown:
            print("Unknown error")
        @unknown default:
            print("Unknown error code")
        }
    }
}
```

---

## Quick Setup Script

Run this to verify configuration:

```bash
#!/bin/bash

echo "Checking Sign in with Apple Setup..."

# Check entitlements
if grep -q "com.apple.developer.applesignin" MovieTrailer/MovieTrailer/MovieTrailer.entitlements; then
    echo "Entitlements configured"
else
    echo "ERROR: Missing entitlements"
fi

# Check .p8 key exists
if [ -f "AppSetUpKit/appsetupkit.p8 copy" ]; then
    echo ".p8 key file found"
else
    echo "ERROR: Missing .p8 key"
fi

echo "Done!"
```

---

## References

- [Apple Sign in with Apple Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Supabase Apple Auth](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Firebase Apple Auth](https://firebase.google.com/docs/auth/ios/apple)

---

Document Version: 1.0
Last Updated: January 2026
