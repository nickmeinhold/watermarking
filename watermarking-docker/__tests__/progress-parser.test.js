const {
  parseMarkingProgressLine,
  calculateEtaText,
  parseDetectionProgressLine,
  parseSizeMismatchError,
} = require("../lib/progress-parser");

describe("parseMarkingProgressLine", () => {
  describe("loading step", () => {
    test("parses PROGRESS:loading", () => {
      const result = parseMarkingProgressLine("PROGRESS:loading");
      expect(result.progressText).toBe("Loading image...");
    });
  });

  describe("marking step", () => {
    test("parses PROGRESS:marking with step info", () => {
      const result = parseMarkingProgressLine("PROGRESS:marking:1:10");
      expect(result.progressText).toBe("Embedding watermark (1/10)");
    });

    test("sets markingStartTime on first step", () => {
      const before = Date.now();
      const result = parseMarkingProgressLine("PROGRESS:marking:1:10", {});
      const after = Date.now();

      expect(result.context.markingStartTime).toBeGreaterThanOrEqual(before);
      expect(result.context.markingStartTime).toBeLessThanOrEqual(after);
    });

    test("includes ETA after first step", () => {
      // Simulate 5 seconds elapsed since start
      const startTime = Date.now() - 5000;
      const result = parseMarkingProgressLine("PROGRESS:marking:3:10", {
        markingStartTime: startTime,
      });

      expect(result.progressText).toMatch(/Embedding watermark \(3\/10\)/);
      expect(result.progressText).toMatch(/remaining/);
    });

    test("updates currentMarkingStatus in context", () => {
      const result = parseMarkingProgressLine("PROGRESS:marking:5:20", {});
      expect(result.context.currentMarkingStatus).toContain(
        "Embedding watermark (5/20)",
      );
    });

    test("handles invalid marking format gracefully", () => {
      const result = parseMarkingProgressLine("PROGRESS:marking:invalid:data");
      expect(result.progressText).toBeNull();
    });
  });

  describe("saving step", () => {
    test("parses PROGRESS:saving", () => {
      const result = parseMarkingProgressLine("PROGRESS:saving");
      expect(result.progressText).toBe("Compressing image...");
    });
  });

  describe("dft step", () => {
    test("appends DFT to current status", () => {
      const result = parseMarkingProgressLine("PROGRESS:dft", {
        currentMarkingStatus: "Embedding watermark (5/10)",
      });
      expect(result.progressText).toBe("Embedding watermark (5/10) - DFT...");
    });

    test("uses Processing when no current status", () => {
      const result = parseMarkingProgressLine("PROGRESS:dft", {});
      expect(result.progressText).toBe("Processing - DFT...");
    });
  });

  describe("idft step", () => {
    test("appends IDFT to current status", () => {
      const result = parseMarkingProgressLine("PROGRESS:idft", {
        currentMarkingStatus: "Embedding watermark (5/10)",
      });
      expect(result.progressText).toBe("Embedding watermark (5/10) - IDFT...");
    });
  });

  describe("edge cases", () => {
    test("returns null for empty line", () => {
      const result = parseMarkingProgressLine("");
      expect(result.progressText).toBeNull();
    });

    test("returns null for null line", () => {
      const result = parseMarkingProgressLine(null);
      expect(result.progressText).toBeNull();
    });

    test("returns null for non-PROGRESS line", () => {
      const result = parseMarkingProgressLine("Some other output");
      expect(result.progressText).toBeNull();
    });

    test("preserves context when no changes", () => {
      const context = { foo: "bar", markingStartTime: 12345 };
      const result = parseMarkingProgressLine("non-progress line", context);
      expect(result.context.foo).toBe("bar");
      expect(result.context.markingStartTime).toBe(12345);
    });
  });
});

describe("calculateEtaText", () => {
  test("returns empty string for first step", () => {
    expect(calculateEtaText(1, 10, 1000)).toBe("");
  });

  test("returns empty string for zero elapsed", () => {
    expect(calculateEtaText(5, 10, 0)).toBe("");
  });

  test("returns empty string for negative elapsed", () => {
    expect(calculateEtaText(5, 10, -1000)).toBe("");
  });

  test("returns empty string when complete", () => {
    expect(calculateEtaText(10, 10, 5000)).toBe("");
  });

  test("calculates seconds remaining correctly", () => {
    // At step 2, 1 step done in 10 seconds, 8 steps remaining = 80 seconds
    const result = calculateEtaText(2, 10, 10000);
    expect(result).toMatch(/1m 20s remaining/);
  });

  test("shows only seconds when less than a minute", () => {
    // At step 5, 4 steps done in 20 seconds (5s each), 5 steps remaining = 25s
    const result = calculateEtaText(5, 10, 20000);
    expect(result).toMatch(/25s remaining/);
    expect(result).not.toMatch(/\dm/); // no digit followed by 'm' (minutes)
  });

  test("formats minutes and seconds correctly", () => {
    // At step 2, 1 step done in 90 seconds, 8 steps remaining = 720s = 12m
    const result = calculateEtaText(2, 10, 90000);
    expect(result).toMatch(/12m 0s remaining/);
  });
});

describe("parseDetectionProgressLine", () => {
  test("extracts progress message", () => {
    const result = parseDetectionProgressLine("PROGRESS:Loading images...");
    expect(result).toBe("Loading images...");
  });

  test("trims whitespace", () => {
    const result = parseDetectionProgressLine("PROGRESS:  Detecting...  ");
    expect(result).toBe("Detecting...");
  });

  test("returns null for non-PROGRESS line", () => {
    expect(parseDetectionProgressLine("Some output")).toBeNull();
  });

  test("returns null for empty line", () => {
    expect(parseDetectionProgressLine("")).toBeNull();
  });

  test("returns null for null", () => {
    expect(parseDetectionProgressLine(null)).toBeNull();
  });
});

describe("parseSizeMismatchError", () => {
  test("returns base message for no stdout", () => {
    const result = parseSizeMismatchError("");
    expect(result).toBe("Different sizes for marked and original images");
  });

  test("returns base message for null stdout", () => {
    const result = parseSizeMismatchError(null);
    expect(result).toBe("Different sizes for marked and original images");
  });

  test("extracts size info when present", () => {
    const stdout = "Error: Original: 1920x1080, Marked: 800x600";
    const result = parseSizeMismatchError(stdout);
    expect(result).toBe(
      "Different sizes for marked and original images (1920x1080 vs 800x600)",
    );
  });

  test("returns base message when no size match", () => {
    const stdout = "Some other error output";
    const result = parseSizeMismatchError(stdout);
    expect(result).toBe("Different sizes for marked and original images");
  });
});
