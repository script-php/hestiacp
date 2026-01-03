# HestiaCP Login System - Complete Analysis

This document provides a comprehensive analysis of the HestiaCP login and authentication system to help you understand how it works for rewriting the project from scratch.

## Table of Contents
1. [System Architecture Overview](#system-architecture-overview)
2. [Login Flow Step-by-Step](#login-flow-step-by-step)
3. [Authentication Mechanisms](#authentication-mechanisms)
4. [Security Features](#security-features)
5. [Session Management](#session-management)
6. [Key Components](#key-components)
7. [User Roles and Permissions](#user-roles-and-permissions)
8. [Password Hashing Methods](#password-hashing-methods)

---

## System Architecture Overview

HestiaCP uses a **multi-tier architecture** for authentication:

```
┌─────────────────────────────────────────────────┐
│          Frontend (PHP Web Interface)           │
│  /web/login/index.php + Template Files          │
└─────────────────┬───────────────────────────────┘
                  │
                  │ Executes via sudo
                  ▼
┌─────────────────────────────────────────────────┐
│       Backend Scripts (Bash/Shell)              │
│  /bin/v-check-user-hash, v-get-user-salt, etc.  │
└─────────────────┬───────────────────────────────┘
                  │
                  │ Reads/Writes
                  ▼
┌─────────────────────────────────────────────────┐
│         User Data Storage (Text Files)          │
│        /usr/local/hestia/data/users/            │
└─────────────────────────────────────────────────┘
```

### Key Design Principles:
- **Separation of Concerns**: Web interface (PHP) is separated from authentication logic (Bash)
- **Privilege Separation**: PHP runs as web user, authentication runs as root via sudo
- **Stateful Sessions**: Uses PHP sessions for maintaining login state
- **Progressive Authentication**: Multi-step login for username → password → 2FA

---

## Login Flow Step-by-Step

### Phase 1: Initial Page Load (`/web/login/index.php`)

1. **Session Initialization** (`/web/inc/main.php`)
   - `session_start()` begins PHP session
   - Security checks are bypassed if `NO_AUTH_REQUIRED` is defined

2. **Existing Session Check** (lines 18-110)
   - If `$_SESSION['user']` exists, user is already logged in
   - Redirects to appropriate dashboard based on user role and features
   - Handles user impersonation for administrators

3. **CSRF Token Generation** (lines 451-453)
   ```php
   $token = bin2hex(random_bytes(16));
   $_SESSION['token'] = $token;
   ```

4. **Template Selection** (lines 456-468)
   - Shows `login.php` for username entry
   - Shows `login_1.php` for password entry  
   - Shows `login_2.php` for 2FA token entry

### Phase 2: Username Submission

**File**: `/web/login/index.php` (lines 411-419)

1. User submits username via POST
2. Username validation using regex:
   ```php
   preg_match('/^[[:alnum:]][-|\.|_[:alnum:]]{0,28}[[:alnum:]]$/', $_POST['user'])
   ```
3. Username stored in `$_SESSION['login']['username']`
4. Template switches to `login_1.php` (password entry form)

### Phase 3: Password Authentication

**File**: `/web/login/index.php` - `authenticate_user()` function (lines 112-410)

#### Step 1: CSRF Verification (line 114)
```php
if (verify_csrf($_POST, true))
```

#### Step 2: IP Address Detection (lines 116-136)
- Extracts real IP from `REMOTE_ADDR`
- Supports CloudFlare's `HTTP_CF_CONNECTING_IP`
- Handles IPv4-mapped IPv6 addresses

#### Step 3: Get User Salt (lines 138-146)
```bash
v-get-user-salt $user $ip json
```
Returns:
```json
{
  "username": {
    "SALT": "random_salt_string",
    "METHOD": "sha-512|md5|yescrypt|des"
  }
}
```

#### Step 4: Hash Password (lines 161-190)
Based on the method returned:

**MD5**:
```php
$hash = crypt($password, '$1$' . $salt . '$');
```

**SHA-512**:
```php
$hash = crypt($password, '$6$rounds=5000$' . $salt . '$');
$hash = str_replace('$rounds=5000', '', $hash);
```

**Yescrypt** (modern, most secure):
```php
// Password written to temp file
exec("v-check-user-password $user $temp_file $ip yes");
```

**DES** (legacy):
```php
$hash = crypt($password, $salt);
```

#### Step 5: Verify Hash (lines 193-207)
```bash
v-check-user-hash $user $hash_file $ip
```
- Hash written to temporary file for security
- Backend script compares with stored hash
- Temporary file immediately deleted

#### Step 6: Failed Login Handling (lines 209-226)
- 2-second delay to prevent brute force
- Login attempt logged via `v-log-user-login`
- Returns error message

#### Step 7: Additional Security Checks (lines 228-276)
If hash is valid:

**Login Disabled Check** (lines 232-250):
```php
if ($data[$user]['LOGIN_DISABLED'] === 'yes')
```

**IP Whitelist Check** (lines 253-276):
```php
if ($data[$user]['LOGIN_USE_IPLIST'] === 'yes') {
    $allowed_ips = explode(',', $data[$user]['LOGIN_ALLOW_IPS']);
    if (!in_array($ip, $allowed_ips))
}
```

### Phase 4: Two-Factor Authentication (2FA)

**File**: `/web/login/index.php` (lines 278-323)

1. **Check if 2FA is enabled** (line 278)
   ```php
   if ($data[$user]['TWOFA'] != '')
   ```

2. **First password entry** (lines 279-282)
   - If no 2FA token provided yet
   - Store username and password in session
   - Display `login_2.php` template (2FA entry form)

3. **2FA Token Verification** (lines 283-322)
   ```bash
   v-check-user-2fa $user $twofa_token
   ```
   - Failed attempts tracked: `$_SESSION['failed_twofa']`
   - After 3 failures, attempts are logged
   - On success, proceeds to session creation

### Phase 5: Session Establishment (lines 325-396)

1. **Create User Session** (line 326)
   ```php
   $_SESSION['user'] = key($data);
   ```

2. **Log Successful Login** (lines 329-342)
   ```bash
   v-log-user-login $user $ip success $session_id $user_agent
   ```

3. **Set Session Variables** (lines 344-365)
   - `$_SESSION['LAST_ACTIVITY']` - for timeout tracking
   - `$_SESSION['userContext']` - user role (admin/user)
   - `$_SESSION['userTheme']` - UI theme
   - `$_SESSION['userSortOrder']` - sorting preference
   - `$_SESSION['language']` - interface language

4. **Session Regeneration** (line 368)
   ```php
   session_regenerate_id(true);
   ```
   Prevents session fixation attacks

5. **Redirect to Dashboard** (lines 371-396)
   - Checks for saved `request_uri` (deep linking)
   - Admins → `/list/user/`
   - Regular users → first available feature page based on package

---

## Authentication Mechanisms

### Password Hash Storage

HestiaCP supports multiple hashing algorithms for backward compatibility:

| Algorithm | Format | Security Level | Usage |
|-----------|--------|----------------|-------|
| **yescrypt** | `$y$...` | Very High (Modern) | Default for new users |
| **SHA-512** | `$6$...` | High | Common for existing users |
| **MD5** | `$1$...` | Medium | Legacy support |
| **DES** | 2-char salt | Low | Very old systems |

### Hash Verification Process

```
┌──────────────┐
│ User enters  │
│   password   │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ v-get-user-salt      │  ← Retrieves salt + method
│ Returns: salt+method │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ PHP hashes password  │  ← Client-side hashing
│ using salt + method  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ v-check-user-hash    │  ← Server compares hashes
│ Compares with stored │
└──────┬───────────────┘
       │
       ▼
    Success/Fail
```

### Why This Architecture?

1. **Security**: Actual password never touches PHP code directly for yescrypt
2. **Privilege Separation**: Only root (via backend scripts) can read password hashes
3. **Flexibility**: Supports multiple hash algorithms for migration

---

## Security Features

### 1. CSRF (Cross-Site Request Forgery) Protection

**Implementation**: `/web/inc/prevent_csrf.php`

#### Token-Based Protection
Every form includes a unique token:
```php
<input type="hidden" name="token" value="<?= $_SESSION['token'] ?>">
```

Verification on submission:
```php
function verify_csrf($method, $return = false) {
    if ($method['token'] !== $_SESSION['token'] || 
        empty($method['token']) || 
        empty($_SESSION['token'])) {
        // Reject request
    }
}
```

#### Origin/Referer Checking
- Validates `HTTP_ORIGIN` for POST requests
- Validates `HTTP_REFERER` for GET requests
- Configurable strictness levels (0-2):
  - **Level 0**: Basic checks
  - **Level 1**: Hostname match required
  - **Level 2**: Exact hostname + system hostname match

### 2. Session Hijacking Prevention

**File**: `/web/inc/main.php` (lines 40-81)

Tracks user's IP signature:
```php
$user_combined_ip = $_SERVER['REMOTE_ADDR'] . '|' . 
                    $_SERVER['HTTP_CLIENT_IP'] . '|' .
                    $_SERVER['HTTP_X_FORWARDED_FOR'] . '|' .
                    $_SERVER['HTTP_CF_CONNECTING_IP'];

if ($_SESSION['user_combined_ip'] != $user_combined_ip) {
    // Session hijacking detected - force logout
    destroy_sessions();
    header('Location: /login/');
}
```

Can be disabled via `$_SESSION['DISABLE_IP_CHECK']`

### 3. Session Timeout

**File**: `/web/inc/main.php` (lines 122-140)

```php
if ($_SESSION['INACTIVE_SESSION_TIMEOUT'] * 60 + 
    $_SESSION['LAST_ACTIVITY'] < time()) {
    // Session expired - logout
    v-log-user-logout $user $session_id
    destroy_sessions();
}
```

### 4. Brute Force Protection

**File**: `/web/login/index.php`

1. **Failed Login Delay** (line 148, 210, 233, 257, 292)
   ```php
   sleep(2); // 2-second delay on each failure
   ```

2. **Login Attempt Logging**
   All attempts logged to `/usr/local/hestia/log/auth.log`

3. **2FA Attempt Tracking** (lines 297-318)
   ```php
   $_SESSION['failed_twofa']++;
   // Logging starts after 3 failed attempts
   ```

### 5. Secure Login URL (Optional)

**File**: `/web/inc/secure_login.php`

- Allows hiding login page behind secret URL parameter
- Cookie-based access after first visit
- Format: `/login/?secret_key`

### 6. Login Access Control

**Per-User IP Whitelist** (lines 253-276):
```php
if ($data[$user]['LOGIN_USE_IPLIST'] === 'yes') {
    $allowed_ips = explode(',', $data[$user]['LOGIN_ALLOW_IPS']);
    if (!in_array($ip, $allowed_ips)) {
        // Deny login
    }
}
```

**Login Disable Flag** (lines 232-250):
```php
if ($data[$user]['LOGIN_DISABLED'] === 'yes') {
    // Prevent login even with correct password
}
```

---

## Session Management

### Session Variables

| Variable | Purpose | Set During |
|----------|---------|------------|
| `$_SESSION['user']` | Logged-in username | Login |
| `$_SESSION['token']` | CSRF protection token | Every page load |
| `$_SESSION['userContext']` | User role (admin/user) | Login |
| `$_SESSION['LAST_ACTIVITY']` | Timestamp for timeout | Every page load |
| `$_SESSION['language']` | Interface language | Login |
| `$_SESSION['userTheme']` | UI theme preference | Login |
| `$_SESSION['look']` | Impersonated user (admins) | Impersonation |
| `$_SESSION['login']['username']` | Temp storage during login | Login process |
| `$_SESSION['login']['password']` | Temp storage during 2FA | 2FA process |
| `$_SESSION['user_combined_ip']` | IP signature | First page load |

### Session Lifecycle

```
┌─────────────────┐
│  session_start()│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  User logs in   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ $_SESSION['user'] set   │
│ $_SESSION['token'] set  │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ session_regenerate_id() │  ← Prevents fixation
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│   User active session   │
│   Timeout tracking      │
│   IP verification       │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Logout/Timeout/Hijack   │
│ destroy_sessions()      │
└─────────────────────────┘
```

### Session Destruction

**File**: `/web/inc/main.php` (lines 30-35)

```php
function destroy_sessions() {
    unset($_SESSION);
    session_unset();
    session_destroy();
    session_start(); // Start fresh session
}
```

Called when:
- User clicks logout
- Session timeout occurs
- Session hijacking detected
- Invalid authentication state

---

## Key Components

### Frontend Components

| File | Purpose |
|------|---------|
| `/web/login/index.php` | Main login controller |
| `/web/logout/index.php` | Logout handler |
| `/web/inc/main.php` | Session management & auth checks |
| `/web/inc/prevent_csrf.php` | CSRF protection |
| `/web/inc/secure_login.php` | Secret URL protection |
| `/web/templates/pages/login/login.php` | Username entry form |
| `/web/templates/pages/login/login_1.php` | Password entry form |
| `/web/templates/pages/login/login_2.php` | 2FA token entry form |

### Backend Scripts (Bash)

| Script | Purpose |
|--------|---------|
| `/bin/v-get-user-salt` | Retrieve password salt & hash method |
| `/bin/v-check-user-hash` | Verify password hash |
| `/bin/v-check-user-password` | Verify password (yescrypt) |
| `/bin/v-check-user-2fa` | Verify 2FA token |
| `/bin/v-log-user-login` | Log login attempts |
| `/bin/v-log-user-logout` | Log logout events |
| `/bin/v-list-user` | Get user configuration |

### Communication Pattern

```php
// PHP calls bash via exec with sudo
exec(HESTIA_CMD . "v-get-user-salt " . $v_user . " " . $v_ip . " json", 
     $output, $return_var);

// Parse JSON response
$pam = json_decode(implode('', $output), true);
```

Where `HESTIA_CMD = /usr/bin/sudo /usr/local/hestia/bin/`

---

## User Roles and Permissions

### Role Types

**Admin** (`$_SESSION['userContext'] === 'admin'`):
- Can view all users: `/list/user/`
- Can impersonate other users
- Access to system settings
- Default landing page: Users list

**Regular User** (`$_SESSION['userContext'] !== 'admin'`):
- Limited to own account
- Landing page based on enabled features
- Cannot access other user accounts

### User Impersonation

**File**: `/web/login/index.php` (lines 20-63)

Process:
1. Admin clicks "Login as" for a user
2. CSRF token verified
3. Check if target user exists
4. Set `$_SESSION['look'] = target_user`
5. Log impersonation event
6. Reset File Manager session
7. Redirect to target user's view

To exit impersonation:
- Admin clicks logout → clears `$_SESSION['look']`
- Returns to admin dashboard

### Feature-Based Routing

Users redirected based on enabled features (in priority order):

1. Web Domains (`WEB_DOMAINS != 0`) → `/list/web/`
2. DNS Domains (`DNS_DOMAINS != 0`) → `/list/dns/`
3. Mail Domains (`MAIL_DOMAINS != 0`) → `/list/mail/`
4. Databases (`DATABASES != 0`) → `/list/db/`
5. Cron Jobs (`CRON_JOBS != 0`) → `/list/cron/`
6. Backups (`BACKUPS != 0`) → `/list/backup/`
7. No features → `/error/`

---

## Password Hashing Methods

### Supported Algorithms

#### 1. Yescrypt (Recommended)
- **Format**: `$y$j9T$salt$hash...`
- **Rounds**: Configurable (higher = slower = more secure)
- **Security**: Most secure, designed for password hashing
- **Special Handling**: Password passed via temporary file to avoid command line exposure

#### 2. SHA-512
- **Format**: `$6$rounds=5000$salt$hash...`
- **Rounds**: 5000 (configurable)
- **Security**: Good for most purposes
- **Implementation**: PHP's `crypt()` function

#### 3. MD5
- **Format**: `$1$salt$hash...`
- **Security**: Acceptable but aging
- **Usage**: Legacy compatibility

#### 4. DES
- **Format**: Two-character salt + 11-character hash
- **Security**: Weak, not recommended
- **Usage**: Very old systems only

### Migration Strategy

When user logs in:
1. Check current hash method
2. If outdated (MD5/DES), can upgrade to SHA-512/yescrypt
3. Re-hash password with stronger algorithm on successful login

---

## Authentication Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    User Visits /login/                   │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
          ┌───────────────────────┐
          │  Session exists?      │
          └─────┬─────────┬───────┘
               Yes        No
                │          │
                ▼          ▼
          ┌─────────┐  ┌──────────────┐
          │Redirect │  │Show username │
          │to home  │  │   form       │
          └─────────┘  └──────┬───────┘
                              │
                              ▼
                     ┌────────────────┐
                     │Submit username │
                     └────────┬───────┘
                              │
                              ▼
                     ┌────────────────┐
                     │Validate regex  │
                     │Store in session│
                     └────────┬───────┘
                              │
                              ▼
                     ┌────────────────┐
                     │Show password   │
                     │     form       │
                     └────────┬───────┘
                              │
                              ▼
                     ┌────────────────┐
                     │Submit password │
                     └────────┬───────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  CSRF Check           │
                  └─────┬─────────────────┘
                        │
                        ▼
                  ┌───────────────────────┐
                  │  Get user salt        │
                  │  (v-get-user-salt)    │
                  └─────┬─────────────────┘
                        │
                        ▼
                  ┌───────────────────────┐
                  │  Hash password        │
                  │  (client-side)        │
                  └─────┬─────────────────┘
                        │
                        ▼
                  ┌───────────────────────┐
                  │  Verify hash          │
                  │  (v-check-user-hash)  │
                  └─────┬─────────┬───────┘
                       Fail      Pass
                        │         │
                        ▼         ▼
                  ┌─────────┐  ┌──────────────┐
                  │sleep(2) │  │Check:        │
                  │Log fail │  │- Login locked│
                  │Show err │  │- IP whitelist│
                  └─────────┘  └──────┬───────┘
                                      │
                                      ▼
                              ┌───────────────┐
                              │ 2FA enabled?  │
                              └───┬───────┬───┘
                                 No      Yes
                                  │       │
                                  │       ▼
                                  │  ┌──────────────┐
                                  │  │Show 2FA form │
                                  │  └──────┬───────┘
                                  │         │
                                  │         ▼
                                  │  ┌──────────────┐
                                  │  │Submit token  │
                                  │  └──────┬───────┘
                                  │         │
                                  │         ▼
                                  │  ┌──────────────┐
                                  │  │Verify 2FA    │
                                  │  │(v-check-2fa) │
                                  │  └──────┬───────┘
                                  │        Pass
                                  ▼         │
                            ┌──────────────────────┐
                            │ Create session       │
                            │ - Set $_SESSION vars │
                            │ - Regenerate ID      │
                            │ - Log success        │
                            └──────┬───────────────┘
                                   │
                                   ▼
                            ┌──────────────────────┐
                            │ Redirect to home     │
                            │ based on role/       │
                            │ features             │
                            └──────────────────────┘
```

---

## Summary for Rewriting

### Core Concepts to Implement

1. **Multi-Step Authentication**
   - Step 1: Username validation
   - Step 2: Password verification  
   - Step 3: 2FA (optional)

2. **Secure Password Handling**
   - Never store passwords in plain text
   - Use strong hashing (yescrypt/SHA-512)
   - Salt every password uniquely
   - Hash verification happens server-side

3. **Session Security**
   - CSRF tokens on every form
   - IP address verification
   - Session timeout tracking
   - Session regeneration after login

4. **Privilege Separation**
   - Web layer (low privilege) calls backend (high privilege)
   - Backend validates and executes privileged operations
   - Communication via command execution + JSON

5. **Comprehensive Logging**
   - Log all login attempts (success/failure)
   - Track session lifecycle
   - Record security events (impersonation, hijacking)

6. **Defense in Depth**
   - Brute force delays
   - IP whitelisting
   - Login disable flag
   - Optional secret URL
   - 2FA support

### Technology Stack Used

- **Frontend**: PHP 7.4+ with sessions
- **Backend**: Bash scripts with sudo execution
- **Data Storage**: Flat files (text-based)
- **Communication**: JSON via exec/shell commands
- **Security**: Multiple layers (CSRF, IP tracking, timeouts)

### Recommendations for Rewrite

1. **Consider Modern Alternatives**:
   - Replace flat files with database (PostgreSQL/MySQL)
   - Use PHP password_hash() with Argon2id
   - Replace exec() calls with PHP native functions
   - Add rate limiting (Redis/Memcached)

2. **Keep These Security Features**:
   - Multi-step authentication
   - CSRF protection
   - Session regeneration
   - Comprehensive logging
   - 2FA support

3. **Potential Improvements**:
   - OAuth2/OpenID Connect integration
   - WebAuthn/FIDO2 support
   - Account lockout after X failures
   - Email/SMS notifications for login
   - Remember device functionality
   - Passwordless authentication options

---

**End of Analysis**

This document covers the complete login system architecture. For specific implementation details, refer to the source files mentioned throughout this document.
