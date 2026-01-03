# HestiaCP Login System - Quick Reference Guide

## Quick File Reference

### Main Entry Points
```
/web/login/index.php          - Main login controller (470 lines)
/web/logout/index.php          - Logout handler
/web/inc/main.php             - Session management & authentication checks
```

### Authentication Backend
```
/bin/v-get-user-salt          - Get password salt & hash method
/bin/v-check-user-hash        - Verify password hash
/bin/v-check-user-password    - Verify password (yescrypt method)
/bin/v-check-user-2fa         - Verify 2FA token
/bin/v-log-user-login         - Log login attempts
/bin/v-log-user-logout        - Log logout events
```

### Login Templates
```
/web/templates/pages/login/login.php    - Username entry form
/web/templates/pages/login/login_1.php  - Password entry form
/web/templates/pages/login/login_2.php  - 2FA token entry form
```

---

## Code Snippets - Copy & Paste

### 1. Starting a Session (from main.php)
```php
session_start();

// Define constants
define('HESTIA_DIR_BIN', '/usr/local/hestia/bin/');
define('HESTIA_CMD', '/usr/bin/sudo /usr/local/hestia/bin/');

// Load configuration
load_hestia_config();
```

### 2. Checking if User is Logged In
```php
if (!isset($_SESSION['user']) && !defined('NO_AUTH_REQUIRED')) {
    destroy_sessions();
    header('Location: /login/');
    exit();
}
```

### 3. Generating CSRF Token
```php
$token = bin2hex(random_bytes(16));
$_SESSION['token'] = $token;
```

### 4. Verifying CSRF Token
```php
function verify_csrf($method, $return = false) {
    if ($method['token'] !== $_SESSION['token'] || 
        empty($method['token']) || 
        empty($_SESSION['token'])) {
        if ($return === true) {
            return false;
        } else {
            header('Location: /login/');
            die();
        }
    }
    return true;
}

// Usage
verify_csrf($_POST);  // Redirect on failure
verify_csrf($_POST, true);  // Return false on failure
```

### 5. Getting User's Password Salt
```php
use function Hestiacp\quoteshellarg\quoteshellarg;

$v_user = quoteshellarg($username);
$v_ip = quoteshellarg($ip_address);

exec(HESTIA_CMD . "v-get-user-salt " . $v_user . " " . $v_ip . " json", 
     $output, $return_var);

if ($return_var > 0) {
    // User not found or suspended
    $error = "Invalid username or password";
} else {
    $pam = json_decode(implode('', $output), true);
    $salt = $pam[$username]['SALT'];
    $method = $pam[$username]['METHOD'];
}
```

### 6. Hashing Password (SHA-512)
```php
$hash = crypt($password, '$6$rounds=5000$' . $salt . '$');
$hash = str_replace('$rounds=5000', '', $hash);
```

### 7. Hashing Password (MD5)
```php
$hash = crypt($password, '$1$' . $salt . '$');
```

### 8. Hashing Password (Yescrypt - Secure Method)
```php
// Create temporary file for password
$fp = tmpfile();
$v_password = stream_get_meta_data($fp)['uri'];
fwrite($fp, $password . "\n");

// Call backend to hash and verify
exec(HESTIA_CMD . "v-check-user-password " . $v_user . " " . 
     quoteshellarg($v_password) . " " . $v_ip . " yes", 
     $output, $return_var);

$hash = $output[0];
fclose($fp);
```

### 9. Verifying Password Hash
```php
// Write hash to temporary file
$v_hash = exec('mktemp -p /tmp');
$fp = fopen($v_hash, 'w');
fwrite($fp, $hash . "\n");
fclose($fp);

// Verify hash
exec(HESTIA_CMD . "v-check-user-hash " . $v_user . " " . $v_hash . " " . $v_ip, 
     $output, $return_var);

// Clean up
unlink($v_hash);

if ($return_var > 0) {
    // Password incorrect
    sleep(2);  // Brute force protection
    $error = "Invalid username or password";
} else {
    // Password correct - proceed
}
```

### 10. Checking 2FA Token
```php
$v_twofa = quoteshellarg($twofa_token);

exec(HESTIA_CMD . "v-check-user-2fa " . $v_user . " " . $v_twofa, 
     $output, $return_var);

if ($return_var > 0) {
    sleep(2);
    $error = "Invalid or missing 2FA token";
} else {
    // 2FA verified
}
```

### 11. Creating User Session
```php
// Get user details
exec(HESTIA_CMD . "v-list-user " . $v_user . " json", $output, $return_var);
$data = json_decode(implode('', $output), true);

// Set session variables
$_SESSION['user'] = key($data);
$_SESSION['LAST_ACTIVITY'] = time();
$_SESSION['userContext'] = $data[$user]['ROLE'];  // 'admin' or other
$_SESSION['userTheme'] = $data[$user]['THEME'];
$_SESSION['language'] = $data[$user]['LANGUAGE'];

// Regenerate session ID (prevent session fixation)
session_regenerate_id(true);

// Log successful login
$v_session_id = quoteshellarg($_SESSION['token']);
$v_user_agent = quoteshellarg($_SERVER['HTTP_USER_AGENT']);

exec(HESTIA_CMD . "v-log-user-login " . $v_user . " " . $v_ip . 
     " success " . $v_session_id . " " . $v_user_agent);
```

### 12. Destroying Session (Logout)
```php
function destroy_sessions() {
    unset($_SESSION);
    session_unset();
    session_destroy();
    session_start();
}

// Before destroying, log the logout
if (isset($_SESSION['user'])) {
    $v_user = quoteshellarg($_SESSION['user']);
    $v_session_id = quoteshellarg($_SESSION['token']);
    exec(HESTIA_CMD . "v-log-user-logout " . $v_user . " " . $v_session_id);
}

destroy_sessions();
header('Location: /login/');
exit();
```

### 13. Checking Session Timeout
```php
if (!defined('NO_AUTH_REQUIRED')) {
    if (empty($_SESSION['LAST_ACTIVITY']) || 
        empty($_SESSION['INACTIVE_SESSION_TIMEOUT'])) {
        destroy_sessions();
        header('Location: /login/');
    } elseif ($_SESSION['INACTIVE_SESSION_TIMEOUT'] * 60 + 
              $_SESSION['LAST_ACTIVITY'] < time()) {
        // Session expired
        $v_user = quoteshellarg($_SESSION['user']);
        $v_session_id = quoteshellarg($_SESSION['token']);
        exec(HESTIA_CMD . "v-log-user-logout " . $v_user . " " . $v_session_id);
        destroy_sessions();
        header('Location: /login/');
        exit();
    } else {
        // Update activity timestamp
        $_SESSION['LAST_ACTIVITY'] = time();
    }
}
```

### 14. IP Address Detection (with CloudFlare support)
```php
$ip = $_SERVER['REMOTE_ADDR'];

// Check for CloudFlare IP
if (!empty($_SERVER['HTTP_CF_CONNECTING_IP']) && 
    filter_var($_SERVER['HTTP_CF_CONNECTING_IP'], 
               FILTER_VALIDATE_IP, 
               FILTER_FLAG_IPV4 | FILTER_FLAG_IPV6)) {
    $ip = $_SERVER['HTTP_CF_CONNECTING_IP'];
}

// Handle IPv4-mapped IPv6 addresses
if (strpos($ip, ':') === 0 && strpos($ip, '.') > 0) {
    $ip = substr($ip, strrpos($ip, ':') + 1);
}
```

### 15. Session Hijacking Prevention
```php
// Build IP signature
$user_combined_ip = $_SERVER['REMOTE_ADDR'];
if (isset($_SERVER['HTTP_CLIENT_IP'])) {
    $user_combined_ip .= '|' . $_SERVER['HTTP_CLIENT_IP'];
}
if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
    $user_combined_ip .= '|' . $_SERVER['HTTP_X_FORWARDED_FOR'];
}
if (isset($_SERVER['HTTP_CF_CONNECTING_IP'])) {
    if (!empty($_SERVER['HTTP_CF_CONNECTING_IP'])) {
        $user_combined_ip = $_SERVER['HTTP_CF_CONNECTING_IP'];
    }
}

// Store on first visit
if (!isset($_SESSION['user_combined_ip'])) {
    $_SESSION['user_combined_ip'] = $user_combined_ip;
}

// Verify on subsequent visits
if ($_SESSION['user_combined_ip'] != $user_combined_ip && 
    isset($_SESSION['user']) && 
    $_SESSION['DISABLE_IP_CHECK'] != 'yes') {
    // Possible session hijacking
    $v_user = quoteshellarg($_SESSION['user']);
    $v_session_id = quoteshellarg($_SESSION['token']);
    exec(HESTIA_CMD . "v-log-user-logout " . $v_user . " " . $v_session_id);
    destroy_sessions();
    header('Location: /login/');
    exit();
}
```

### 16. User Impersonation (Admin Feature)
```php
// Check if admin is trying to impersonate
if ($_SESSION['userContext'] === 'admin' && !empty($_GET['loginas'])) {
    // Verify CSRF token
    if (verify_csrf($_GET)) {
        $v_user = quoteshellarg($_GET['loginas']);
        $v_impersonator = quoteshellarg($_SESSION['user']);
        
        // Check if target user exists
        exec(HESTIA_CMD . "v-list-user " . $v_user . " json", $output, $return_var);
        
        if ($return_var == 0) {
            $data = json_decode(implode('', $output), true);
            $_SESSION['look'] = key($data);
            
            // Log impersonation
            exec(HESTIA_CMD . "v-log-action " . $v_impersonator . 
                 " 'Info' 'Security' 'Logged in as another user (User: $v_user)'");
            exec(HESTIA_CMD . "v-log-action system 'Warning' 'Security' " .
                 "'User impersonation session started (User: $v_user, Admin: $v_impersonator)'");
            
            header('Location: /login/');
        }
    }
}

// Exit impersonation
if (!empty($_SESSION['look'])) {
    unset($_SESSION['look']);
    header('Location: /');
}
```

### 17. Username Validation Regex
```php
// Validates username format
if (preg_match('/^[[:alnum:]][-|\.|_[:alnum:]]{0,28}[[:alnum:]]$/', $_POST['user'])) {
    $username = $_POST['user'];
} else {
    $error = "Invalid username format";
}

// Rules:
// - Must start and end with alphanumeric character
// - Can contain: letters, numbers, dash, dot, underscore
// - Length: 2-30 characters
```

### 18. Loading System Configuration
```php
function load_hestia_config() {
    exec(HESTIA_CMD . "v-list-sys-config json", $output, $return_var);
    $data = json_decode(implode('', $output), true);
    $sys_arr = $data['config'];
    
    foreach ($sys_arr as $key => $value) {
        $_SESSION[$key] = $value;
    }
}

// Sets session variables like:
// - $_SESSION['VERSION']
// - $_SESSION['LANGUAGE']
// - $_SESSION['INACTIVE_SESSION_TIMEOUT']
// - $_SESSION['POLICY_SYSTEM_PASSWORD_RESET']
// etc.
```

---

## Common Patterns

### Pattern 1: Execute Backend Command
```php
use function Hestiacp\quoteshellarg\quoteshellarg;

$v_param = quoteshellarg($user_input);
exec(HESTIA_CMD . "v-command-name " . $v_param . " json", $output, $return_var);

if ($return_var > 0) {
    // Command failed
    $error = "Operation failed";
} else {
    // Command succeeded
    $result = json_decode(implode('', $output), true);
}
```

### Pattern 2: Progressive Form Flow
```php
// Step 1: Show username form
if (empty($_SESSION['login']['username'])) {
    require_once 'templates/login.php';
}

// Step 2: Show password form
elseif (empty($_SESSION['login']['password'])) {
    require_once 'templates/login_1.php';
}

// Step 3: Show 2FA form
elseif (!empty($_SESSION['login']['password']) && $twofa_required) {
    require_once 'templates/login_2.php';
}
```

### Pattern 3: Redirect Based on Role
```php
if ($_SESSION['userContext'] === 'admin') {
    header('Location: /list/user/');
} else {
    // Redirect to first available feature
    if ($data[$user]['WEB_DOMAINS'] != '0') {
        header('Location: /list/web/');
    } elseif ($data[$user]['DNS_DOMAINS'] != '0') {
        header('Location: /list/dns/');
    } // ... etc
}
exit();
```

---

## Session Variables Reference

| Variable | Type | Purpose | Example |
|----------|------|---------|---------|
| `$_SESSION['user']` | string | Logged-in username | `'admin'` |
| `$_SESSION['token']` | string | CSRF token | `'a1b2c3d4e5f6...'` |
| `$_SESSION['userContext']` | string | User role | `'admin'` or `'user'` |
| `$_SESSION['look']` | string | Impersonated user | `'john'` |
| `$_SESSION['LAST_ACTIVITY']` | int | Unix timestamp | `1704307200` |
| `$_SESSION['INACTIVE_SESSION_TIMEOUT']` | int | Timeout in minutes | `30` |
| `$_SESSION['language']` | string | Interface language | `'en'` |
| `$_SESSION['userTheme']` | string | UI theme | `'dark'` |
| `$_SESSION['userSortOrder']` | string | Sort preference | `'name'` |
| `$_SESSION['login']['username']` | string | Temp during login | `'admin'` |
| `$_SESSION['login']['password']` | string | Temp during 2FA | `'password'` |
| `$_SESSION['user_combined_ip']` | string | IP signature | `'192.168.1.1\|...'` |
| `$_SESSION['failed_twofa']` | int | Failed 2FA attempts | `3` |
| `$_SESSION['VERSION']` | string | HestiaCP version | `'1.8.0'` |
| `$_SESSION['APP_NAME']` | string | Application name | `'Hestia'` |

---

## Backend Script Return Codes

Common return codes from backend scripts:

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error / Unsupported hash method |
| `5` | User suspended |
| `9` | Authentication failed |

---

## Security Checklist for Implementation

- [ ] Hash all passwords (never store plain text)
- [ ] Use unique salts per user
- [ ] Implement CSRF tokens on all forms
- [ ] Track session IP addresses
- [ ] Implement session timeout
- [ ] Regenerate session ID after login
- [ ] Add brute force delay (sleep on failure)
- [ ] Log all authentication attempts
- [ ] Support 2FA
- [ ] Validate all user input
- [ ] Use prepared statements (if using SQL)
- [ ] Sanitize shell arguments with quoteshellarg
- [ ] Implement rate limiting
- [ ] Add account lockout after X failures
- [ ] Use HTTPS for all pages
- [ ] Set secure session cookie flags
- [ ] Implement password complexity requirements
- [ ] Add password reset functionality
- [ ] Support IP whitelisting
- [ ] Allow disabling login per user

---

## Testing Checklist

### Authentication Tests
- [ ] Valid username + valid password = success
- [ ] Valid username + invalid password = failure
- [ ] Invalid username + any password = failure  
- [ ] Account with LOGIN_DISABLED = failure
- [ ] IP not in whitelist (when enabled) = failure
- [ ] Suspended account = failure
- [ ] 2FA enabled + wrong token = failure
- [ ] 2FA enabled + correct token = success

### Session Tests
- [ ] Session timeout after inactivity = redirect to login
- [ ] Session persists across page loads
- [ ] IP change = session destroyed
- [ ] CSRF token mismatch = reject request
- [ ] Logout clears all session data

### Security Tests
- [ ] Password never appears in logs
- [ ] Failed login triggers delay
- [ ] Multiple failures logged correctly
- [ ] Session fixation prevented
- [ ] XSS attempts sanitized
- [ ] SQL injection prevented (if using DB)

---

## File Structure for Rewrite

Recommended structure:
```
/login/
  index.php          - Main controller
  authenticate.php   - Authentication logic class
  
/includes/
  session.php        - Session management class
  csrf.php           - CSRF protection class
  security.php       - Security utilities
  
/templates/
  login/
    username.php     - Username form
    password.php     - Password form
    twofa.php        - 2FA form
    
/classes/
  Auth.php           - Authentication class
  User.php           - User model
  Session.php        - Session manager
  Logger.php         - Logging class
  
/config/
  config.php         - Configuration file
  constants.php      - Define constants
```

---

**For complete details, see LOGIN_SYSTEM_ANALYSIS.md**
