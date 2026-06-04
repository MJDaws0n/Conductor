# Login Signup Terminal App

Run:

```sh
python3 app.py
```

The app stores users and settings in `users.db`. Passwords are hashed with
PBKDF2-SHA256 and per-user random salts; plaintext passwords are never stored.

On first run, if no admin exists, the app creates:

```text
username: admin
password: admin123
```

Change that password after first login.

Useful commands:

```text
main> signup
main> login
admin> list
admin> edit USERNAME
admin> reset USERNAME
admin> delete USERNAME
```

Non-interactive check:

```sh
python3 app.py --self-test
```
