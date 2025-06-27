const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = 4200;

// Proxy API requests to Django
app.use('/api', createProxyMiddleware({
  target: 'http://localhost:8000',
  changeOrigin: true,
  secure: false
}));

// Proxy WebSocket requests to Django
app.use('/ws', createProxyMiddleware({
  target: 'http://localhost:8000',
  changeOrigin: true,
  secure: false,
  ws: true
}));

// Serve static files from dist folder (when built)
app.use(express.static(path.join(__dirname, 'dist')));

// Handle all other routes by serving index.html (for client-side routing)
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
  console.log('This server handles client-side routing properly');
}); 