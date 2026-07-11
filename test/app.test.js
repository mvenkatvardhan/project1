const request = require('supertest');
const app = require('../src/app');

describe('GET /', () => {
  it('responds with a welcome message', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBeDefined();
  });
});

describe('GET /health', () => {
  it('responds with status UP', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('UP');
  });
});
