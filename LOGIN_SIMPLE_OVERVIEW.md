# HestiaCP Login System - Simple Overview

## What is it?

HestiaCP uses a **multi-step, secure login system** with separation between the web interface (PHP) and authentication backend (Bash scripts).

## 5-Minute Understanding

### Architecture in Simple Terms

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       │ HTTP Request
       ▼
┌─────────────────────────┐
│  PHP Web Application    │  ← Handles UI, forms, sessions
│  (Low privilege user)   │
└──────┬──────────────────┘
       │
       │ exec() with sudo
       ▼
┌─────────────────────────┐
│  Bash Scripts           │  ← Handles authentication
│  (Root privilege)       │
└──────┬──────────────────┘
       │
       │ Read/Write
       ▼
┌─────────────────────────┐
│  User Data Files        │  ← Stores password hashes
│  (Text files)           │
└─────────────────────────┘
```

### The Login Process (3 Steps)

**Step 1: Enter Username**
- User visits `/login/`
- Enters username
- Username validated with regex
- Stored in session

**Step 2: Enter Password**
1. Backend fetches password salt and hash method
2. PHP hashes the password with the salt
3. Backend compares hash with stored hash
4. If user has 2FA enabled, go to Step 3
5. If no 2FA, create session and login

**Step 3: Enter 2FA Token (if enabled)**
- User enters 6-digit code from authenticator app
- Backend verifies token
- Create session and login

### What Happens When You Login?

```php
// 1. Session variables are set
$_SESSION['user'] = 'admin';
$_SESSION['token'] = 'abc123...';  // CSRF protection
$_SESSION['LAST_ACTIVITY'] = 1704307200;  // For timeout
$_SESSION['userContext'] = 'admin';  // Role

// 2. Session ID is regenerated (security)
session_regenerate_id(true);

// 3. Login is logged
v-log-user-login admin 192.168.1.1 success

// 4. User is redirected to dashboard
header('Location: /list/user/');
```

### What Happens When You Logout?

```php
// 1. Logout is logged
v-log-user-logout admin abc123...

// 2. Session is destroyed
unset($_SESSION);
session_destroy();

// 3. Redirect to login
header('Location: /login/');
```

## Key Security Features

### 1. CSRF Protection
Every form has a hidden token that must match the session token:
```html
<input type="hidden" name="token" value="<?= $_SESSION['token'] ?>">
```

### 2. Session Timeout
If you're inactive for 30 minutes (configurable), you're logged out.

### 3. IP Tracking
Your IP address is recorded at login. If it changes, session is destroyed (can be disabled).

### 4. Brute Force Protection
Failed login = 2 second delay before trying again.

### 5. Password Hashing
Passwords are hashed with:
- **Yescrypt** (most secure, newest)
- **SHA-512** (secure, common)
- **MD5** (legacy)
- **DES** (very old)

### 6. Two-Factor Authentication (2FA)
Optional 6-digit code from authenticator app.

## Main Files

### Frontend (PHP)
| File | What It Does |
|------|--------------|
| `/web/login/index.php` | Main login logic |
| `/web/logout/index.php` | Logout handler |
| `/web/inc/main.php` | Session checks on every page |

### Backend (Bash)
| File | What It Does |
|------|--------------|
| `/bin/v-get-user-salt` | Get password salt |
| `/bin/v-check-user-hash` | Verify password |
| `/bin/v-check-user-2fa` | Verify 2FA code |
| `/bin/v-log-user-login` | Log login events |

## How PHP Calls Bash

```php
// PHP side
$v_user = quoteshellarg('admin');
exec('/usr/bin/sudo /usr/local/hestia/bin/v-list-user ' . $v_user . ' json', 
     $output, $return_var);

// Backend returns JSON
$data = json_decode(implode('', $output), true);
```

## Session Flow

```
Visit /login/
     │
     ▼
Session started (session_start())
     │
     ▼
Generate CSRF token
     │
     ▼
Show username form
     │
     ▼
Submit username → Validate → Store in session
     │
     ▼
Show password form
     │
     ▼
Submit password → Hash → Verify → Success?
     │                                 │
     ▼                                 ▼
    Yes                               No
     │                                 │
     ▼                                 ▼
   2FA?                      Sleep 2 sec + Show error
     │
     ▼
Show 2FA form
     │
     ▼
Submit token → Verify → Success?
     │                      │
     ▼                      ▼
    Yes                    No
     │                      │
     ▼                      ▼
Create Session      Sleep 2 sec + Show error
     │
     ▼
session_regenerate_id()
     │
     ▼
Redirect to dashboard
```

## User Roles

**Admin**:
- Can see all users
- Can impersonate other users (login as them)
- Lands on `/list/user/` after login

**Regular User**:
- Can only see their own account
- Lands on first available feature page (Web, DNS, Mail, etc.)

## Impersonation (Admin Feature)

Admin can "login as" another user:
1. Admin clicks "Login as user123"
2. `$_SESSION['look'] = 'user123'` is set
3. Admin now sees user123's account
4. To exit: logout (clears `$_SESSION['look']`)

## Password Verification Example

```php
// User enters password: "MyPassword123"

// 1. Get salt and method
exec('v-get-user-salt admin 192.168.1.1 json', ...);
// Returns: { "admin": { "SALT": "xyz", "METHOD": "sha-512" } }

// 2. Hash the password
$hash = crypt('MyPassword123', '$6$rounds=5000$xyz$');
// Result: $6$xyz$abcdef123456...

// 3. Write hash to temp file
$tmpfile = '/tmp/hash123';
file_put_contents($tmpfile, $hash);

// 4. Verify hash
exec('v-check-user-hash admin /tmp/hash123 192.168.1.1', ...);
// Return code: 0 = success, >0 = failure

// 5. Delete temp file
unlink($tmpfile);
```

## Important Session Variables

| Variable | What It Stores |
|----------|----------------|
| `$_SESSION['user']` | Logged-in username |
| `$_SESSION['token']` | CSRF token |
| `$_SESSION['userContext']` | User role (admin/user) |
| `$_SESSION['LAST_ACTIVITY']` | Timestamp for timeout |
| `$_SESSION['look']` | Impersonated user (admin only) |

## Common Checks on Every Page

File: `/web/inc/main.php`

```php
// 1. Is user logged in?
if (!isset($_SESSION['user'])) {
    header('Location: /login/');
    exit();
}

// 2. Has session timed out?
if ($_SESSION['LAST_ACTIVITY'] + (30 * 60) < time()) {
    destroy_sessions();
    header('Location: /login/');
    exit();
}

// 3. Did IP address change?
if ($_SESSION['user_combined_ip'] != $current_ip) {
    destroy_sessions();
    header('Location: /login/');
    exit();
}

// 4. Update activity timestamp
$_SESSION['LAST_ACTIVITY'] = time();
```

## Why This Design?

**Separation of Privileges**:
- PHP runs as `www-data` (low privilege)
- Can't directly access password hashes
- Must call bash scripts via sudo
- Bash scripts run as root
- Only root can read `/usr/local/hestia/data/users/`

**Benefits**:
- ✅ Web layer can't be exploited to read passwords
- ✅ Clear separation of concerns
- ✅ Easier to audit security

**Drawbacks**:
- ❌ Slower (process creation overhead)
- ❌ Hard to debug
- ❌ Requires sudo configuration

## Rewrite Recommendations

### Modern Approach

Instead of:
```
PHP → exec() → Bash → Text Files
```

Use:
```
PHP → Database (with proper privileges)
```

### Better Password Handling

Instead of:
```php
crypt($password, '$6$rounds=5000$' . $salt . '$')
```

Use:
```php
password_hash($password, PASSWORD_ARGON2ID);
password_verify($password, $hash);
```

### Replace exec() Calls

Instead of:
```php
exec('v-list-user admin json', $output, $return_var);
```

Use:
```php
$user = User::find('admin');  // ORM/Model
```

### Add Modern Features

- Rate limiting (Redis/Memcached)
- OAuth2/OpenID Connect
- WebAuthn/FIDO2
- Remember device
- Email notifications
- Account lockout
- Passwordless authentication

## Testing Your Understanding

Can you answer these?

1. **Q**: What happens if you change your IP address mid-session?
   **A**: Session is destroyed and you're logged out (unless `DISABLE_IP_CHECK` is enabled)

2. **Q**: Why is there a 2-second delay on failed login?
   **A**: Brute force protection - makes automated attacks slower

3. **Q**: Where are password hashes stored?
   **A**: In text files under `/usr/local/hestia/data/users/[username]/`

4. **Q**: What's the purpose of `session_regenerate_id()`?
   **A**: Prevents session fixation attacks by changing session ID after login

5. **Q**: Can a regular user impersonate another user?
   **A**: No, only admins (`$_SESSION['userContext'] === 'admin'`)

6. **Q**: What's stored in `$_SESSION['look']`?
   **A**: The username of the user being impersonated by an admin

7. **Q**: Why are CSRF tokens used?
   **A**: To prevent Cross-Site Request Forgery attacks

8. **Q**: How is the password passed to yescrypt hashing?
   **A**: Written to a temporary file (to avoid command line exposure)

## Summary

HestiaCP login is:
- ✅ **Multi-layered**: Username → Password → 2FA
- ✅ **Secure**: CSRF, IP tracking, timeouts, hashing
- ✅ **Separated**: PHP UI ↔ Bash backend
- ✅ **Logged**: All attempts recorded
- ✅ **Flexible**: Supports 2FA, impersonation, IP whitelisting

For rewrite:
- Consider database instead of flat files
- Use native PHP password functions
- Add modern features (OAuth, WebAuthn)
- Keep the security features (CSRF, timeouts, logging)

---

**Next Steps**:
1. Read `LOGIN_SYSTEM_ANALYSIS.md` for complete details
2. Read `LOGIN_QUICK_REFERENCE.md` for code snippets
3. Review actual source code in `/web/login/index.php`
4. Understand your requirements for the rewrite
5. Choose your tech stack
6. Design your architecture
7. Implement with security in mind

Good luck with your rewrite! 🚀
