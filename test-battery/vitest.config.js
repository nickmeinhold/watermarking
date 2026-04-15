import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    testTimeout: 300_000, // 5 min per test (detection can be slow)
    hookTimeout: 600_000, // 10 min for beforeAll (marking is very slow)
    pool: 'forks',
    poolOptions: {
      forks: { singleFork: true }, // Serial — Docker container has limited CPU
    },
    reporters: ['default'],
  },
});
