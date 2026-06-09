#!/usr/bin/env node
const { readStdin } = require('./adapter');

readStdin()
  .then(raw => {
    try {
      const input = JSON.parse(raw || '{}');
      const filePath = input.path || input.file || '';
      if (/\.(env|key|pem)$|\.env\.|credentials|secret/i.test(filePath)) {
        console.error('[ECC] BLOCKED: Tab read of sensitive file: ' + filePath);
        process.stdout.write(JSON.stringify({
          permission: 'deny',
          user_message: 'Tab cannot read sensitive files.',
        }));
        return;
      }
    } catch {
      // noop
    }
    process.stdout.write(JSON.stringify({ permission: 'allow' }));
  })
  .catch(() => {
    process.stdout.write(JSON.stringify({ permission: 'allow' }));
  });
