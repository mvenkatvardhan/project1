const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.status(200).json({ message: 'Hello from the Node.js CI/CD Pipeline Demo!' });
});

// Used by Docker HEALTHCHECK and by monitoring/uptime checks
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP' });
});

// Only start listening when run directly (keeps it importable in tests)
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

module.exports = app;
