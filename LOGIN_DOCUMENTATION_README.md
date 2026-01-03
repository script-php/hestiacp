# HestiaCP Login System Documentation

This directory contains comprehensive documentation of the HestiaCP login and authentication system.

## 📚 Documentation Files

### 1. [LOGIN_SIMPLE_OVERVIEW.md](LOGIN_SIMPLE_OVERVIEW.md) - **START HERE**
**Best for**: Quick understanding in 5-10 minutes

A simplified explanation of how the login system works:
- Simple architecture diagram
- 3-step login process explained
- Key security features overview
- Main files reference
- Common questions answered

**Who should read this**: Anyone wanting a quick understanding before diving deeper.

---

### 2. [LOGIN_QUICK_REFERENCE.md](LOGIN_QUICK_REFERENCE.md)
**Best for**: Developers implementing the system

Copy-paste ready code snippets:
- File reference guide
- 18+ code snippets for common tasks
- Session management patterns
- Backend script return codes
- Security & testing checklists
- Recommended file structure for rewrite

**Who should read this**: Developers building or rewriting the authentication system.

---

### 3. [LOGIN_SYSTEM_ANALYSIS.md](LOGIN_SYSTEM_ANALYSIS.md)
**Best for**: Complete system understanding

Comprehensive deep-dive covering:
- Complete architecture breakdown
- Step-by-step authentication flow
- All security features explained
- Session management details
- Password hashing methods
- User roles and permissions
- Visual flow diagrams
- Recommendations for rewriting

**Who should read this**: System architects, security auditors, or anyone needing complete understanding.

---

## 🎯 Quick Navigation

**I want to...**

- **Understand how login works** → Read [LOGIN_SIMPLE_OVERVIEW.md](LOGIN_SIMPLE_OVERVIEW.md)
- **Copy code snippets** → Read [LOGIN_QUICK_REFERENCE.md](LOGIN_QUICK_REFERENCE.md)
- **Deep dive into security** → Read [LOGIN_SYSTEM_ANALYSIS.md](LOGIN_SYSTEM_ANALYSIS.md)
- **Rewrite the system** → Read all three, starting with Overview

---

## 🔑 Key Concepts

### Architecture Pattern
```
Browser → PHP Web Layer → Bash Scripts → User Data Files
          (Low privilege)  (Root access)  (Password hashes)
```

### Login Process
1. **Username entry** → Validation → Store in session
2. **Password entry** → Get salt → Hash → Verify
3. **2FA entry** (if enabled) → Verify token → Create session

### Security Layers
- ✅ CSRF protection (tokens on all forms)
- ✅ Session timeout (configurable, default 30 min)
- ✅ IP tracking (prevents session hijacking)
- ✅ Brute force delays (2 seconds per failed attempt)
- ✅ Password hashing (yescrypt/SHA-512/MD5)
- ✅ Two-factor authentication (optional)
- ✅ Comprehensive logging (all auth events)

---

## 📊 System Statistics

| Metric | Value |
|--------|-------|
| Main controller size | ~470 lines (login/index.php) |
| Frontend files | 8 PHP files |
| Backend scripts | 6+ bash scripts |
| Login steps | 2-3 (username, password, 2FA) |
| Hash algorithms supported | 4 (yescrypt, SHA-512, MD5, DES) |
| Session variables | 15+ tracked |
| Security features | 10+ implemented |

---

## 🔐 Security Features Summary

| Feature | Implementation | File |
|---------|---------------|------|
| CSRF Protection | Token verification | prevent_csrf.php |
| Session Timeout | Activity tracking | main.php |
| IP Verification | Combined IP signature | main.php |
| Brute Force | 2-second delay | login/index.php |
| Password Hashing | Multiple algorithms | login/index.php |
| 2FA Support | TOTP verification | login/index.php |
| Login Logging | All attempts logged | v-log-user-login |
| Session Fixation | ID regeneration | login/index.php |
| IP Whitelist | Per-user IPs | login/index.php |
| Login Disable | Per-user flag | login/index.php |

---

## 🛠️ For Developers Rewriting

### Current Stack
- **Frontend**: PHP 7.4+ with sessions
- **Backend**: Bash scripts
- **Storage**: Text files
- **Communication**: exec() + JSON
- **Hashing**: crypt() with multiple methods

### Recommended Modern Stack
- **Frontend**: PHP 8.2+ or Node.js
- **Backend**: Native PHP or API
- **Storage**: PostgreSQL/MySQL
- **Communication**: Database queries or REST API
- **Hashing**: password_hash() with Argon2id

### What to Keep
✅ Multi-step authentication flow  
✅ CSRF protection  
✅ Session regeneration  
✅ Comprehensive logging  
✅ 2FA support  
✅ Role-based access  

### What to Improve
🔄 Replace exec() calls with native code  
🔄 Use database instead of flat files  
🔄 Add rate limiting  
🔄 Add account lockout  
🔄 Add OAuth2/OpenID Connect  
🔄 Add WebAuthn support  
🔄 Improve error handling  
🔄 Add audit trails  

---

## 📖 Reading Order

### For Quick Understanding
1. Read **LOGIN_SIMPLE_OVERVIEW.md** (10 min)
2. Skim **LOGIN_QUICK_REFERENCE.md** (5 min)
3. Done! You understand the basics.

### For Implementation
1. Read **LOGIN_SIMPLE_OVERVIEW.md** (10 min)
2. Read **LOGIN_SYSTEM_ANALYSIS.md** (30 min)
3. Reference **LOGIN_QUICK_REFERENCE.md** while coding
4. Review actual source code in `/web/login/`

### For Security Audit
1. Read **LOGIN_SYSTEM_ANALYSIS.md** completely (30 min)
2. Check security features section
3. Review backend scripts in `/bin/`
4. Test each security feature manually

---

## 🔍 Key Files in Repository

### Frontend (PHP)
```
/web/login/index.php                    - Main login controller (470 lines)
/web/logout/index.php                   - Logout handler
/web/inc/main.php                       - Session management
/web/inc/prevent_csrf.php               - CSRF protection
/web/inc/secure_login.php               - Secret URL feature
/web/templates/pages/login/login.php    - Username form
/web/templates/pages/login/login_1.php  - Password form
/web/templates/pages/login/login_2.php  - 2FA form
```

### Backend (Bash)
```
/bin/v-get-user-salt         - Get password salt & method
/bin/v-check-user-hash       - Verify password hash
/bin/v-check-user-password   - Verify yescrypt password
/bin/v-check-user-2fa        - Verify 2FA token
/bin/v-log-user-login        - Log login attempts
/bin/v-log-user-logout       - Log logout events
/bin/v-list-user             - Get user details
```

---

## 💡 Common Questions

**Q: Can I use this documentation to rewrite HestiaCP?**  
A: Yes! That's exactly what it's for. The analysis covers everything you need to understand and reimplement the login system.

**Q: Is the current system secure?**  
A: Yes, it implements many security best practices. See the Security Features section in LOGIN_SYSTEM_ANALYSIS.md.

**Q: Why does PHP call Bash scripts?**  
A: Privilege separation. The web server (PHP) runs as low-privilege user, while authentication requires root access to read password hashes.

**Q: What's the best hashing algorithm?**  
A: Yescrypt (newest, most secure). For new projects, use Argon2id via PHP's password_hash().

**Q: How do I test the login system?**  
A: See the Testing Checklist in LOGIN_QUICK_REFERENCE.md.

**Q: Can I improve the current system?**  
A: Yes! See "Recommendations for Rewrite" in LOGIN_SYSTEM_ANALYSIS.md.

---

## 📝 Contributing

If you find errors or want to improve this documentation:
1. The documentation is based on HestiaCP source code analysis
2. Main source: `/web/login/index.php` and related files
3. All diagrams and explanations are derived from actual code
4. Submit improvements via pull request

---

## 📄 License

This documentation is provided as-is to help understand the HestiaCP login system. The actual HestiaCP code is licensed under GPL v3.

---

## 🙏 Acknowledgments

This documentation was created by analyzing the HestiaCP open-source project:
- Repository: https://github.com/hestiacp/hestiacp
- Website: https://hestiacp.com/
- Documentation: https://docs.hestiacp.com/

---

**Last Updated**: January 2026  
**HestiaCP Version Analyzed**: Latest (as of analysis date)

---

**Ready to start?** Begin with [LOGIN_SIMPLE_OVERVIEW.md](LOGIN_SIMPLE_OVERVIEW.md) 🚀
