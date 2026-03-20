#!/usr/bin/env node

/**
 * AppSetupKit - Multi-Platform App Launch Automation
 * Updated: February 2026
 *
 * Supports:
 * - Native iOS (Swift 6.2 / Xcode 26 / SPM)
 * - Expo SDK 54 (stable) / React Native 0.81 / React 19.1
 *
 * Services:
 * - App Store Connect (Fastlane 2.232+)
 * - Firebase (iOS SDK 12.x, JS modular API)
 * - Supabase (PKCE auth, Management API)
 * - RevenueCat (iOS 5.x, RN 9.x)
 * - MCP servers for AI-assisted development
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const readline = require('readline');
const https = require('https');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const question = (q) => new Promise((resolve) => rl.question(q, resolve));

// Colors
const C = {
    RESET: "\x1b[0m", RED: "\x1b[31m", GREEN: "\x1b[32m", YELLOW: "\x1b[33m",
    BLUE: "\x1b[34m", CYAN: "\x1b[36m", MAGENTA: "\x1b[35m", BOLD: "\x1b[1m", DIM: "\x1b[2m"
};

const log = (msg, color = C.RESET) => console.log(`${color}${msg}${C.RESET}`);
const ok = (msg) => log(`  [ok] ${msg}`, C.GREEN);
const fail = (msg) => log(`  [!!] ${msg}`, C.RED);
const info = (msg) => log(`  [..] ${msg}`, C.BLUE);
const warn = (msg) => log(`  [!!] ${msg}`, C.YELLOW);
const section = (msg) => log(`\n${C.BOLD}${C.MAGENTA}--- ${msg} ---${C.RESET}\n`);

// State
const STATE_FILE = 'setup-state.json';
let state = { step: 'init', config: {}, credentials: {} };

function loadState() {
    if (fs.existsSync(STATE_FILE)) {
        try {
            state = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
            info("Resuming from saved state...");
        } catch { /* start fresh */ }
    }
}

function saveState() {
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function run(command, cwd = process.cwd(), opts = {}) {
    try {
        log(`  $ ${command}`, C.DIM);
        const result = execSync(command, {
            cwd,
            encoding: 'utf8',
            stdio: opts.capture ? 'pipe' : 'inherit',
            timeout: opts.timeout || 120000
        });
        return opts.capture ? result.trim() : true;
    } catch (e) {
        if (!opts.ignoreError) fail(`Command failed: ${command}`);
        if (opts.capture) return null;
        return false;
    }
}

function httpPatch(url, headers, data) {
    return new Promise((resolve, reject) => {
        const urlObj = new URL(url);
        const body = JSON.stringify(data);
        const req = https.request({
            hostname: urlObj.hostname, path: urlObj.pathname + urlObj.search,
            method: 'PATCH',
            headers: { ...headers, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
        }, (res) => {
            let chunks = '';
            res.on('data', c => chunks += c);
            res.on('end', () => {
                try { resolve({ status: res.statusCode, data: JSON.parse(chunks) }); }
                catch { resolve({ status: res.statusCode, data: chunks }); }
            });
        });
        req.on('error', reject);
        req.write(body);
        req.end();
    });
}

// ---- STEPS ----

async function gatherConfig() {
    if (state.config.appName) return;
    section("Configuration");

    log("Select project type:", C.CYAN);
    log("  1. Expo / React Native (SDK 54 + RN 0.81)");
    log("  2. Native iOS (Swift 6.2 / Xcode 26 / SPM)");
    const typeInput = await question("Choice (1 or 2): ");
    state.config.projectType = typeInput.trim() === '2' ? 'swift' : 'expo';

    state.config.appName = await question("App Name: ");
    state.config.bundleId = await question("iOS Bundle ID (e.g. com.company.app): ");

    if (state.config.projectType === 'expo') {
        state.config.packageId = await question("Android Package Name: ") || state.config.bundleId;
    }

    state.config.appleId = await question("Apple ID Email: ");
    state.config.teamId = await question("Apple Team ID: ");
    state.config.slug = state.config.appName.toLowerCase().replace(/[^a-z0-9]+/g, '-');

    // Metadata (optional)
    log("\nApp Store Metadata (press Enter to skip):", C.BOLD);
    state.config.subtitle = await question("Subtitle (max 30 chars): ");
    state.config.keywords = await question("Keywords (comma-separated, max 100 chars): ");

    // Auth
    log("\nAuthentication:", C.BOLD);
    state.config.appleAuth = (await question("Enable Sign in with Apple? (y/n): ")).toLowerCase() === 'y';
    state.config.googleAuth = (await question("Enable Google Sign-In? (y/n): ")).toLowerCase() === 'y';

    if (state.config.appleAuth) {
        state.config.appleServicesId = await question("Apple Services ID (e.g. com.company.app.signin): ");
    }

    saveState();
}

async function setupProject() {
    if (state.step !== 'init') return;
    const { appName, slug, bundleId, projectType } = state.config;
    const projectPath = path.join(process.cwd(), slug);

    section(`Step 1: ${projectType === 'expo' ? 'Expo SDK 54' : 'Swift/Xcode 26'} Project`);

    if (projectType === 'expo') {
        if (!fs.existsSync(projectPath)) {
            info("Creating Expo project (SDK 54 stable, TypeScript)...");
            // SDK 54 is the current stable - uses RN 0.81, React 19.1
            run(`npx create-expo-app@latest "${slug}" --template blank-typescript`);
        } else {
            info("Project directory exists, skipping creation.");
        }

        info("Initializing EAS...");
        run(`npx eas-cli@latest init --non-interactive`, projectPath, { ignoreError: true });
        run(`npx eas-cli@latest build:configure --platform all`, projectPath, { ignoreError: true });

        // Create eas.json with development profile for dev client builds
        const easJsonPath = path.join(projectPath, 'eas.json');
        if (!fs.existsSync(easJsonPath)) {
            const easJson = {
                cli: { version: ">= 16.0.1", appVersionSource: "remote" },
                build: {
                    production: { autoIncrement: true },
                    development: { autoIncrement: true, developmentClient: true }
                },
                submit: { production: {}, development: {} }
            };
            fs.writeFileSync(easJsonPath, JSON.stringify(easJson, null, 2));
            ok("eas.json created with development + production profiles.");
        }
    } else {
        if (!fs.existsSync(projectPath)) fs.mkdirSync(projectPath, { recursive: true });

        // Generate project.yml for XcodeGen
        const projectYml = `name: ${appName.replace(/\s/g, '')}
options:
  bundleIdPrefix: ${bundleId.split('.').slice(0, -1).join('.')}
  deploymentTarget:
    iOS: "18.0"
  xcodeVersion: "26.2"
settings:
  base:
    DEVELOPMENT_TEAM: ${state.config.teamId}
    SWIFT_VERSION: "6.2"
    IPHONEOS_DEPLOYMENT_TARGET: "18.0"
targets:
  ${appName.replace(/\s/g, '')}:
    type: application
    platform: iOS
    sources:
      - ${appName.replace(/\s/g, '')}
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: ${bundleId}
    dependencies: []
`;
        fs.writeFileSync(path.join(projectPath, 'project.yml'), projectYml);

        // Create source directory and files
        const srcDir = path.join(projectPath, appName.replace(/\s/g, ''));
        if (!fs.existsSync(srcDir)) fs.mkdirSync(srcDir, { recursive: true });

        fs.writeFileSync(path.join(srcDir, `${appName.replace(/\s/g, '')}App.swift`), `import SwiftUI

@main
struct ${appName.replace(/\s/g, '')}App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
`);
        fs.writeFileSync(path.join(srcDir, 'ContentView.swift'), `import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, ${appName}!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
`);
        ok("Swift project scaffolded with XcodeGen config.");
        info("Run 'xcodegen generate' in the project directory to create .xcodeproj");
    }

    state.step = 'appstore';
    saveState();
}

async function setupAppStore() {
    if (state.step !== 'appstore') return;
    const { appName, bundleId, slug, teamId } = state.config;
    const projectPath = path.join(process.cwd(), slug);
    const fastlaneDir = path.join(projectPath, 'fastlane');

    section("Step 2: App Store Connect (Fastlane 2.232+)");

    fs.mkdirSync(fastlaneDir, { recursive: true });

    // Copy .p8 key
    const p8Src = path.join(process.cwd(), 'appsetupkit.p8');
    if (fs.existsSync(p8Src)) {
        fs.copyFileSync(p8Src, path.join(fastlaneDir, 'auth_key.p8'));
        ok("API key copied.");
    } else {
        warn("appsetupkit.p8 not found. Fastlane lanes won't authenticate.");
    }

    // Read credentials
    let keyId = "PRKWBSZ4FZ";
    let issuerId = "d379ef5a-740b-4b80-bc48-8e1526fc03d3";
    const credFile = path.join(process.cwd(), 'appsetupkit.json');
    if (fs.existsSync(credFile)) {
        try {
            const creds = JSON.parse(fs.readFileSync(credFile, 'utf8'));
            keyId = creds.key_id || keyId;
            issuerId = creds.issuer_id || issuerId;
        } catch { /* use defaults */ }
    }

    // Fastfile
    fs.writeFileSync(path.join(fastlaneDir, 'Fastfile'), `
api_key = app_store_connect_api_key(
  key_id: "${keyId}",
  issuer_id: "${issuerId}",
  key_filepath: "./fastlane/auth_key.p8",
  duration: 1200
)

default_platform(:ios)

platform :ios do

  desc "Register app in App Store Connect and enable capabilities"
  lane :setup do
    produce(
      app_identifier: "${bundleId}",
      app_name: "${appName}",
      language: "English",
      app_version: "1.0.0",
      sku: "${bundleId}.sku",
      api_key: api_key,
      skip_itc: false
    )

    enable_app_capability(
      app_identifier: "${bundleId}",
      capability: "push_notifications",
      api_key: api_key
    )

    enable_app_capability(
      app_identifier: "${bundleId}",
      capability: "sign_in_with_apple",
      api_key: api_key
    )

    UI.success("App registered with capabilities enabled!")
  end

  desc "Upload metadata to App Store Connect"
  lane :metadata do
    deliver(
      api_key: api_key,
      app_identifier: "${bundleId}",
      skip_binary_upload: true,
      skip_screenshots: false,
      force: true,
      metadata_path: "./fastlane/metadata",
      submit_for_review: false,
      automatic_release: false,
      precheck_include_in_app_purchases: false
    )
  end

  desc "Build for App Store"
  lane :build do
    build_app(
      scheme: "${appName.replace(/\s/g, '')}",
      export_method: "app-store",
      output_directory: "./build"
    )
  end

  desc "Build and upload to TestFlight"
  lane :beta do
    build
    upload_to_testflight(api_key: api_key)
  end

  desc "Build and submit for App Review"
  lane :release do
    build
    deliver(
      api_key: api_key,
      submit_for_review: true,
      automatic_release: false
    )
  end

end
`);

    // Appfile
    fs.writeFileSync(path.join(fastlaneDir, 'Appfile'), `app_identifier("${bundleId}")
apple_id("${state.config.appleId}")
team_id("${teamId}")
`);

    // Metadata
    const metaDir = path.join(fastlaneDir, 'metadata', 'en-US');
    fs.mkdirSync(metaDir, { recursive: true });
    const meta = {
        'name.txt': appName,
        'subtitle.txt': state.config.subtitle || 'Your app subtitle here',
        'keywords.txt': state.config.keywords || 'app,mobile,utility,productivity,tool,best,new,2026',
        'description.txt': `${appName} - Built for you.\n\nFeatures:\n- Feature 1\n- Feature 2\n- Feature 3\n\nDownload now!`,
        'promotional_text.txt': 'Now available! Download today.',
        'privacy_url.txt': 'https://yourapp.com/privacy',
        'support_url.txt': 'https://yourapp.com/support',
        'marketing_url.txt': 'https://yourapp.com',
        'release_notes.txt': 'Initial release.\n\n- Launch version\n- Core functionality'
    };
    for (const [file, content] of Object.entries(meta)) {
        fs.writeFileSync(path.join(metaDir, file), content);
    }
    fs.mkdirSync(path.join(metaDir, '..', '..', 'screenshots', 'en-US'), { recursive: true });
    ok("Fastlane config + metadata created.");

    // Try running setup
    info("Running Fastlane setup lane...");
    run(`fastlane setup`, projectPath, { ignoreError: true });

    state.step = 'supabase';
    saveState();
}

async function setupSupabase() {
    if (state.step !== 'supabase') return;
    const { appName } = state.config;

    section("Step 3: Supabase (PKCE auth, Management API)");

    try {
        const orgsJson = run(`supabase orgs list --output json`, process.cwd(), { capture: true });
        if (!orgsJson) throw new Error("CLI not available");
        const orgs = JSON.parse(orgsJson);

        if (orgs.length === 0) {
            warn("No Supabase organizations found. Create one at https://supabase.com/dashboard");
        } else {
            log("  Organizations:");
            orgs.forEach((o, i) => log(`    ${i + 1}. ${o.name} (${o.id})`));

            const orgIdx = await question(`  Select (1-${orgs.length}): `);
            const org = orgs[parseInt(orgIdx) - 1];

            if (org) {
                const dbPass = await question("  Database password (min 8 chars): ");
                run(`supabase projects create "${appName}" --org-id ${org.id} --db-password "${dbPass}" --region us-east-1`);

                const projectsJson = run(`supabase projects list --output json`, process.cwd(), { capture: true });
                if (projectsJson) {
                    const projects = JSON.parse(projectsJson);
                    const proj = projects.find(p => p.name === appName);
                    if (proj) {
                        state.credentials.supabaseRef = proj.id;
                        state.credentials.supabaseUrl = `https://${proj.id}.supabase.co`;
                        ok(`Supabase project: ${proj.id}`);

                        // Configure auth providers
                        if (state.config.appleAuth || state.config.googleAuth) {
                            const token = await question("  Supabase access token (from https://supabase.com/dashboard/account/tokens): ");
                            const baseUrl = `https://api.supabase.com/v1/projects/${proj.id}/config/auth`;
                            const headers = { 'Authorization': `Bearer ${token}` };

                            // Enable PKCE (default in 2026)
                            await httpPatch(baseUrl, headers, {
                                EXTERNAL_EMAIL_ENABLED: true,
                                SITE_URL: 'https://yourapp.com',
                                JWT_EXP: 3600,
                                REFRESH_TOKEN_ROTATION_ENABLED: true
                            });

                            if (state.config.appleAuth && fs.existsSync(path.join(process.cwd(), 'appsetupkit.p8'))) {
                                const appleKey = fs.readFileSync(path.join(process.cwd(), 'appsetupkit.p8'), 'utf8');
                                const res = await httpPatch(baseUrl, headers, {
                                    EXTERNAL_APPLE_ENABLED: true,
                                    EXTERNAL_APPLE_CLIENT_ID: state.config.appleServicesId,
                                    EXTERNAL_APPLE_SECRET: appleKey,
                                    EXTERNAL_APPLE_REDIRECT_URI: `https://${proj.id}.supabase.co/auth/v1/callback`
                                });
                                res.status < 300 ? ok("Apple Sign-In configured.") : warn("Apple Sign-In config may need manual setup.");
                            }

                            if (state.config.googleAuth) {
                                const gClientId = await question("  Google OAuth Client ID: ");
                                const gSecret = await question("  Google OAuth Client Secret: ");
                                const res = await httpPatch(baseUrl, headers, {
                                    EXTERNAL_GOOGLE_ENABLED: true,
                                    EXTERNAL_GOOGLE_CLIENT_ID: gClientId,
                                    EXTERNAL_GOOGLE_SECRET: gSecret,
                                    EXTERNAL_GOOGLE_REDIRECT_URI: `https://${proj.id}.supabase.co/auth/v1/callback`
                                });
                                res.status < 300 ? ok("Google Sign-In configured.") : warn("Google Sign-In config may need manual setup.");
                            }
                        }
                    }
                }
            }
        }
    } catch {
        warn("Supabase CLI not available. Run 'supabase login' first, or skip.");
    }

    state.step = 'firebase';
    saveState();
}

async function setupFirebase() {
    if (state.step !== 'firebase') return;
    const { appName, bundleId, packageId, slug, projectType } = state.config;
    const projectPath = path.join(process.cwd(), slug);

    section("Step 4: Firebase (iOS SDK 12.x / JS modular)");

    const fbId = `${slug}-${Date.now().toString().slice(-6)}`;
    state.credentials.firebaseProjectId = fbId;

    run(`firebase projects:create ${fbId} --display-name "${appName}"`, process.cwd(), { ignoreError: true });

    info("Enabling Google Cloud APIs...");
    run(`gcloud config set project ${fbId}`, process.cwd(), { ignoreError: true });
    run(`gcloud services enable identitytoolkit.googleapis.com`, process.cwd(), { ignoreError: true });
    run(`gcloud services enable iap.googleapis.com`, process.cwd(), { ignoreError: true });

    if (state.config.googleAuth) {
        run(`gcloud iap oauth-brands create --application_title="${appName}" --support_email="${state.config.appleId}"`, process.cwd(), { ignoreError: true });
    }

    // iOS app
    run(`firebase apps:create IOS --project ${fbId} --bundle-id ${bundleId} --display-name "${appName} iOS"`, process.cwd(), { ignoreError: true });
    const appsJson = run(`firebase apps:list --project ${fbId} --json`, process.cwd(), { capture: true, ignoreError: true });
    if (appsJson) {
        try {
            const apps = JSON.parse(appsJson);
            const iosApp = apps.result?.find(a => a.platform === 'IOS');
            if (iosApp) {
                run(`firebase apps:sdkconfig IOS ${iosApp.appId} --project ${fbId} --out "${path.join(projectPath, 'GoogleService-Info.plist')}"`, process.cwd(), { ignoreError: true });
                ok("GoogleService-Info.plist downloaded.");
            }
        } catch { /* continue */ }
    }

    // Android app (Expo only)
    if (projectType === 'expo' && packageId) {
        run(`firebase apps:create ANDROID --project ${fbId} --package-name ${packageId} --display-name "${appName} Android"`, process.cwd(), { ignoreError: true });
        const updJson = run(`firebase apps:list --project ${fbId} --json`, process.cwd(), { capture: true, ignoreError: true });
        if (updJson) {
            try {
                const updApps = JSON.parse(updJson);
                const andApp = updApps.result?.find(a => a.platform === 'ANDROID');
                if (andApp) {
                    run(`firebase apps:sdkconfig ANDROID ${andApp.appId} --project ${fbId} --out "${path.join(projectPath, 'google-services.json')}"`, process.cwd(), { ignoreError: true });
                    ok("google-services.json downloaded.");
                }
            } catch { /* continue */ }
        }
    }

    state.step = 'dependencies';
    saveState();
}

async function installDependencies() {
    if (state.step !== 'dependencies') return;
    const { slug, projectType, bundleId, appName, packageId } = state.config;
    const projectPath = path.join(process.cwd(), slug);

    section("Step 5: Dependencies & Configuration");

    if (projectType === 'expo') {
        // Use `npx expo install` to ensure SDK 54-compatible versions
        // This resolves correct peer dependency versions automatically
        info("Installing Expo SDK 54 packages via 'npx expo install'...");
        const packages = [
            'expo-apple-authentication',
            'expo-blur',
            'expo-clipboard',
            'expo-constants',
            'expo-font',
            'expo-haptics',
            'expo-image',
            'expo-linear-gradient',
            'expo-linking',
            'expo-notifications',
            'expo-router',
            'expo-status-bar',
            'expo-web-browser',
            'expo-secure-store',
            'react-native-gesture-handler',
            'react-native-reanimated',
            'react-native-safe-area-context',
            'react-native-screens',
            'react-native-svg',
            '@react-native-async-storage/async-storage'
        ];
        run(`npx expo install ${packages.join(' ')}`, projectPath, { ignoreError: true });

        // These are not Expo-managed, install with npm
        info("Installing third-party packages...");
        const npmPackages = [
            '@react-native-google-signin/google-signin',
            'react-native-purchases',
            'react-native-purchases-ui',
            '@supabase/supabase-js',
            '@firebase/app',
            '@firebase/auth',
            'zustand'
        ];
        run(`npm install ${npmPackages.join(' ')}`, projectPath, { ignoreError: true });

        // Configure app.json following Expo best practices
        const appJsonPath = path.join(projectPath, 'app.json');
        if (fs.existsSync(appJsonPath)) {
            const appJson = JSON.parse(fs.readFileSync(appJsonPath, 'utf8'));
            appJson.expo.name = appName;
            appJson.expo.slug = slug;
            appJson.expo.scheme = slug;
            appJson.expo.userInterfaceStyle = "automatic";
            appJson.expo.newArchEnabled = true; // SDK 54 supports this flag (last SDK before it's removed in 55)
            appJson.expo.ios = {
                ...appJson.expo.ios,
                supportsTablet: true,
                bundleIdentifier: bundleId,
                googleServicesFile: "./GoogleService-Info.plist"
            };
            appJson.expo.android = {
                ...appJson.expo.android,
                package: packageId || bundleId,
                googleServicesFile: "./google-services.json",
                edgeToEdgeEnabled: true
            };
            appJson.expo.web = {
                bundler: "metro",
                output: "single"
            };

            // Plugins - expo-router, expo-font, expo-web-browser are standard
            appJson.expo.plugins = [
                "expo-router",
                "expo-font",
                "expo-web-browser",
                "@react-native-google-signin/google-signin",
                "expo-apple-authentication",
                ["expo-notifications", { icon: "./assets/icon.png", color: "#ffffff", sounds: [] }],
                ["expo-build-properties", { ios: { useFrameworks: "static" } }]
            ];

            // Enable typed routes
            appJson.expo.experiments = { typedRoutes: true };

            fs.writeFileSync(appJsonPath, JSON.stringify(appJson, null, 2));
            ok("app.json configured for SDK 54.");
        }

        // Create src/config.ts (not in app/ directory per Expo Router convention)
        const srcDir = path.join(projectPath, 'src');
        if (!fs.existsSync(srcDir)) fs.mkdirSync(srcDir, { recursive: true });

        fs.writeFileSync(path.join(srcDir, 'config.ts'), `export const Config = {
  appName: "${appName}",
  bundleId: "${bundleId}",
  packageId: "${packageId || bundleId}",
  firebase: { projectId: "${state.credentials.firebaseProjectId || ''}" },
  supabase: {
    url: "${state.credentials.supabaseUrl || 'YOUR_SUPABASE_URL'}",
    anonKey: "YOUR_SUPABASE_ANON_KEY"
  },
  revenueCat: {
    appleApiKey: "YOUR_RC_APPLE_KEY",
    googleApiKey: "YOUR_RC_GOOGLE_KEY"
  }
} as const;
`);
        ok("src/config.ts created (components/config outside app/ directory).");

    } else {
        // Swift - SPM only (CocoaPods sunsetting Dec 2026)
        info("Swift project uses Swift Package Manager (CocoaPods sunset Dec 2, 2026).");

        const projName = appName.replace(/\s/g, '');
        const srcDir = path.join(projectPath, projName);
        if (!fs.existsSync(srcDir)) fs.mkdirSync(srcDir, { recursive: true });

        fs.writeFileSync(path.join(srcDir, 'AppConfig.swift'), `import Foundation

struct AppConfig {
    static let appName = "${appName}"
    static let bundleId = "${bundleId}"

    struct Supabase {
        static let url = "${state.credentials.supabaseUrl || "YOUR_SUPABASE_URL"}"
        static let anonKey = "YOUR_SUPABASE_ANON_KEY"
    }

    struct Firebase {
        static let projectId = "${state.credentials.firebaseProjectId || "YOUR_FIREBASE_PROJECT_ID"}"
    }

    struct RevenueCat {
        static let apiKey = "YOUR_REVENUECAT_API_KEY"
    }
}
`);
        ok("AppConfig.swift created.");

        // SPM dependency instructions
        log("\n  Add these SPM packages in Xcode:", C.CYAN);
        log("    - https://github.com/firebase/firebase-ios-sdk (12.x)");
        log("    - https://github.com/google/GoogleSignIn-iOS");
        log("    - https://github.com/supabase/supabase-swift");
        log("    - https://github.com/RevenueCat/purchases-ios (5.x)");
        log("    - https://github.com/onevcat/Kingfisher");
    }

    state.step = 'mcp';
    saveState();
}

async function setupMCP() {
    if (state.step !== 'mcp') return;
    const { slug, projectType } = state.config;
    const projectPath = path.join(process.cwd(), slug);

    section("Step 6: MCP Server Configuration");

    const mcpConfig = { mcpServers: {} };

    // Firebase MCP
    mcpConfig.mcpServers.firebase = {
        command: "npx",
        args: ["-y", "firebase-tools@latest", "mcp"]
    };

    // Supabase MCP
    mcpConfig.mcpServers.supabase = {
        transport: "http",
        url: "https://mcp.supabase.com/mcp"
    };

    // RevenueCat MCP
    mcpConfig.mcpServers.revenuecat = {
        transport: "http",
        url: "https://mcp.revenuecat.ai/mcp",
        headers: { Authorization: "Bearer YOUR_REVENUECAT_SECRET_KEY" }
    };

    // App Store Connect MCP
    mcpConfig.mcpServers['app-store-connect'] = {
        command: "npx",
        args: ["@joshuarileydev/app-store-connect-mcp-server"]
    };

    // Xcode MCP (Swift only)
    if (projectType === 'swift') {
        mcpConfig.mcpServers.xcode = {
            command: "npx",
            args: ["xcodebuildmcp@latest"]
        };
        mcpConfig.mcpServers['apple-docs'] = {
            command: "npx",
            args: ["apple-doc-mcp-server@latest"]
        };
    }

    // Expo MCP (Expo only)
    if (projectType === 'expo') {
        mcpConfig.mcpServers.expo = {
            transport: "http",
            url: "https://mcp.expo.dev/mcp",
            env: { EXPO_TOKEN: "YOUR_EXPO_TOKEN" }
        };
    }

    // GitHub MCP
    mcpConfig.mcpServers.github = {
        transport: "http",
        url: "https://api.githubcopilot.com/mcp/"
    };

    const configPath = path.join(projectPath, 'mcp-config.json');
    fs.writeFileSync(configPath, JSON.stringify(mcpConfig, null, 2));
    ok("MCP config created at mcp-config.json");

    log("\n  Copy to your Claude Code settings:", C.CYAN);
    log("    macOS: ~/Library/Application Support/Claude/claude_desktop_config.json");
    log("    Or add to .claude/settings.json in your project\n");

    state.step = 'complete';
    saveState();
}

async function setupRevenueCat() {
    if (state.step !== 'revenuecat') return;
    const { appName, bundleId, packageId, projectType } = state.config;

    section("Step 7: RevenueCat");

    info("RevenueCat does not have a CLI for project creation.");
    info("However, the RevenueCat MCP server is configured so Claude Code can help.");
    log("");
    log("  Quick setup (2 minutes):", C.BOLD);
    log(`  1. Go to https://app.revenuecat.com/overview`);
    log(`  2. Create project "${appName}"`);
    log(`  3. Add iOS app: bundle ID = ${bundleId}`);
    if (projectType === 'expo' && packageId) {
        log(`  4. Add Android app: package name = ${packageId}`);
    }
    log(`  5. Upload your .p8 key in Settings > Integrations > App Store Connect`);
    log(`  6. Copy your public API key(s) and update:`);

    if (projectType === 'expo') {
        log(`     - src/config.ts (appleApiKey, googleApiKey)`);
    } else {
        log(`     - AppConfig.swift (RevenueCat.apiKey)`);
    }
    log(`  7. Copy your secret API key and update:`);
    log(`     - mcp-config.json (revenuecat > headers > Authorization)`);
    log("");

    const rcKey = await question("  Paste RevenueCat Apple API key now (or press Enter to skip): ");
    if (rcKey.trim()) {
        state.credentials.rcAppleKey = rcKey.trim();
        ok("RevenueCat Apple API key saved. Will be injected into config files.");
    }

    if (projectType === 'expo') {
        const rcGoogleKey = await question("  Paste RevenueCat Google API key (or Enter to skip): ");
        if (rcGoogleKey.trim()) {
            state.credentials.rcGoogleKey = rcGoogleKey.trim();
        }
    }

    const rcSecret = await question("  Paste RevenueCat secret API key for MCP (or Enter to skip): ");
    if (rcSecret.trim()) {
        state.credentials.rcSecretKey = rcSecret.trim();
    }

    // Patch config files with the keys
    const slug = state.config.slug;
    const projectPath = path.join(process.cwd(), slug);

    if (projectType === 'expo') {
        const configPath = path.join(projectPath, 'src', 'config.ts');
        if (fs.existsSync(configPath)) {
            let content = fs.readFileSync(configPath, 'utf8');
            if (state.credentials.rcAppleKey) {
                content = content.replace('YOUR_RC_APPLE_KEY', state.credentials.rcAppleKey);
            }
            if (state.credentials.rcGoogleKey) {
                content = content.replace('YOUR_RC_GOOGLE_KEY', state.credentials.rcGoogleKey);
            }
            fs.writeFileSync(configPath, content);
            ok("src/config.ts updated with RevenueCat keys.");
        }
    } else {
        const projName = appName.replace(/\s/g, '');
        const configPath = path.join(projectPath, projName, 'AppConfig.swift');
        if (fs.existsSync(configPath) && state.credentials.rcAppleKey) {
            let content = fs.readFileSync(configPath, 'utf8');
            content = content.replace('YOUR_REVENUECAT_API_KEY', state.credentials.rcAppleKey);
            fs.writeFileSync(configPath, content);
            ok("AppConfig.swift updated with RevenueCat key.");
        }
    }

    // Patch MCP config
    if (state.credentials.rcSecretKey) {
        const mcpPath = path.join(projectPath, 'mcp-config.json');
        if (fs.existsSync(mcpPath)) {
            let content = fs.readFileSync(mcpPath, 'utf8');
            content = content.replace('YOUR_REVENUECAT_SECRET_KEY', state.credentials.rcSecretKey);
            fs.writeFileSync(mcpPath, content);
            ok("mcp-config.json updated with RevenueCat secret key.");
        }
    }

    state.step = 'finalize';
    saveState();
}

async function finalize() {
    if (state.step !== 'finalize') return;
    const { slug, projectType, appName } = state.config;
    const projectPath = path.join(process.cwd(), slug);

    section("Step 8: Final Setup");

    // Fetch Supabase anon key if we have the ref
    if (state.credentials.supabaseRef) {
        info("Fetching Supabase API keys...");
        const keysJson = run(`supabase projects api-keys --project-ref ${state.credentials.supabaseRef} --output json`, process.cwd(), { capture: true, ignoreError: true });
        if (keysJson) {
            try {
                const keys = JSON.parse(keysJson);
                const anonKey = keys.find(k => k.name === 'anon');
                if (anonKey) {
                    state.credentials.supabaseAnonKey = anonKey.api_key;

                    // Patch into config files
                    if (projectType === 'expo') {
                        const configPath = path.join(projectPath, 'src', 'config.ts');
                        if (fs.existsSync(configPath)) {
                            let content = fs.readFileSync(configPath, 'utf8');
                            content = content.replace('YOUR_SUPABASE_ANON_KEY', anonKey.api_key);
                            fs.writeFileSync(configPath, content);
                        }
                    } else {
                        const projName = appName.replace(/\s/g, '');
                        const configPath = path.join(projectPath, projName, 'AppConfig.swift');
                        if (fs.existsSync(configPath)) {
                            let content = fs.readFileSync(configPath, 'utf8');
                            content = content.replace('YOUR_SUPABASE_ANON_KEY', anonKey.api_key);
                            fs.writeFileSync(configPath, content);
                        }
                    }
                    ok("Supabase anon key auto-injected into config.");
                }
            } catch { /* skip */ }
        }
    }

    // Git init for Expo projects
    if (projectType === 'expo' && !fs.existsSync(path.join(projectPath, '.git'))) {
        info("Initializing git repository...");
        run(`git init`, projectPath, { ignoreError: true });

        const gitignore = `# Dependencies
node_modules/

# Expo
.expo/
dist/
web-build/

# EAS
*.ipa
*.apk
*.aab

# Native builds
ios/
android/

# Environment
.env
.env.local
.env.production

# Secrets
GoogleService-Info.plist
google-services.json
fastlane/auth_key.p8

# State
setup-state.json

# Other
.DS_Store
*.swp
`;
        fs.writeFileSync(path.join(projectPath, '.gitignore'), gitignore);
        run(`git add . && git commit -m "Initial commit: ${appName} (Expo SDK 54)"`, projectPath, { ignoreError: true });
        ok("Git repository initialized with .gitignore.");
    }

    // Create .env template
    const envContent = `# Environment Variables
# Restart dev server after changes
# Only EXPO_PUBLIC_ vars are exposed to the client bundle

EXPO_PUBLIC_SUPABASE_URL=${state.credentials.supabaseUrl || 'YOUR_SUPABASE_URL'}
EXPO_PUBLIC_SUPABASE_ANON_KEY=${state.credentials.supabaseAnonKey || 'YOUR_SUPABASE_ANON_KEY'}
EXPO_PUBLIC_FIREBASE_PROJECT_ID=${state.credentials.firebaseProjectId || 'YOUR_FIREBASE_PROJECT_ID'}

# Server-side only (never prefix with EXPO_PUBLIC_)
# REVENUECAT_SECRET_KEY=sk_xxx
# SUPABASE_SERVICE_ROLE_KEY=xxx
`;

    if (projectType === 'expo') {
        fs.writeFileSync(path.join(projectPath, '.env.example'), envContent);
        ok(".env.example created (copy to .env and fill in values).");
    }

    // MCP step flows into revenuecat
    state.step = 'revenuecat';
    saveState();
}

async function showSummary() {
    const { appName, slug, bundleId, projectType } = state.config;

    section("Setup Complete!");

    log(`  App: ${appName}`, C.GREEN);
    log(`  Bundle: ${bundleId}`);
    log(`  Type: ${projectType === 'expo' ? 'Expo SDK 54 / React Native 0.81' : 'Swift 6.2 / Xcode 26'}`, C.GREEN);
    log(`  Location: ./${slug}/`);

    // Show what was configured
    log("\n  Configured services:", C.BOLD);
    if (state.credentials.supabaseUrl) {
        log(`    Supabase: ${state.credentials.supabaseUrl}`, C.GREEN);
        if (state.credentials.supabaseAnonKey) log(`    Anon key: injected into config`, C.GREEN);
    }
    if (state.credentials.firebaseProjectId) log(`    Firebase: ${state.credentials.firebaseProjectId}`, C.GREEN);
    if (state.credentials.rcAppleKey) log(`    RevenueCat: Apple key injected`, C.GREEN);
    if (state.credentials.rcSecretKey) log(`    RevenueCat MCP: secret key injected`, C.GREEN);

    // Show what still needs manual work
    const todo = [];
    if (!state.credentials.supabaseAnonKey) todo.push("Fill in Supabase anon key in config");
    if (!state.credentials.rcAppleKey) todo.push("Add RevenueCat API keys (https://app.revenuecat.com)");
    if (!state.credentials.rcSecretKey) todo.push("Add RevenueCat secret key to mcp-config.json");
    if (projectType === 'swift') todo.push("Add SPM packages in Xcode (Firebase 12.x, RevenueCat 5.x, Supabase, Kingfisher)");
    todo.push("Add app icon (1024x1024) and screenshots");
    todo.push("Create privacy policy and support pages");

    if (todo.length > 0) {
        log("\n  Still needs manual work:", C.YELLOW);
        todo.forEach(t => log(`    - ${t}`, C.YELLOW));
    }

    log("\n  Commands:", C.BOLD);
    log(`  cd ${slug}`);

    if (projectType === 'expo') {
        log("");
        log("  Development:", C.CYAN);
        log("    npx expo start                    # Start dev server (try Expo Go first!)");
        log("    eas build -p ios --profile development --submit  # Dev client via TestFlight");
        log("");
        log("  Production:", C.CYAN);
        log("    eas build --platform ios           # Production iOS build");
        log("    fastlane metadata                  # Upload App Store metadata");
        log("    fastlane beta                      # Build + TestFlight (native Fastlane)");
        log("");
        log("  NOTE: RevenueCat (react-native-purchases) requires a dev client build.", C.YELLOW);
        log("  It will NOT work in Expo Go. Use: eas build --profile development", C.YELLOW);
    } else {
        log("");
        log("  Development:", C.CYAN);
        log("    xcodegen generate                  # Generate Xcode project");
        log("    open *.xcodeproj                   # Open in Xcode");
        log("");
        log("  Production:", C.CYAN);
        log("    fastlane beta                      # Build + upload to TestFlight");
        log("    fastlane release                   # Submit for App Review");
    }

    log("\n  Versions:", C.DIM);
    log("  Xcode 26.2 / Swift 6.2 / iOS 26 SDK", C.DIM);
    log("  Fastlane 2.232+ / App Store Connect API 4.2", C.DIM);
    log("  Firebase iOS 12.x / Supabase (PKCE default)", C.DIM);
    log("  RevenueCat iOS 5.59+ / RN 9.7+", C.DIM);
    if (projectType === 'expo') {
        log("  Expo SDK 54 (stable) / React Native 0.81 / React 19.1", C.DIM);
        log("  Expo Router v6 / New Architecture enabled", C.DIM);
        log("  Node.js 20+ works, 22 LTS recommended", C.DIM);
    }
    log("");
}

async function main() {
    log(`\n${C.BOLD}${C.MAGENTA}  AppSetupKit v3.0 - February 2026${C.RESET}\n`);
    loadState();

    await gatherConfig();
    await setupProject();
    await setupAppStore();
    await setupSupabase();
    await setupFirebase();
    await installDependencies();
    await setupMCP();
    await setupRevenueCat();
    await finalize();
    await showSummary();

    rl.close();
}

main().catch(e => {
    fail("Fatal error:");
    console.error(e);
    rl.close();
    process.exit(1);
});
