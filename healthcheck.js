const http = require('http');

const options = {
  hostname: 'localhost',
  port: process.env.OPENCLAW_PORT || 18789,
  path: '/',
  method: 'GET',
  timeout: 2000
};

const request = http.request(options, (res) => {
  if (res.statusCode >= 200 && res.statusCode < 400) {
    process.exit(0);
  } else {
    process.exit(1);
  }
});

request.on('error', () => {
  process.exit(1);
});

request.on('timeout', () => {
  request.destroy();
  process.exit(1);
});

request.end();
