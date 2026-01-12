const {
  stripExtension,
  ensurePngExtension,
  buildMarkedImagePath,
  buildDetectingImagePath,
  buildTempPath
} = require('../lib/path-utils');

describe('stripExtension', () => {
  test('strips .jpg extension', () => {
    expect(stripExtension('image.jpg')).toBe('image');
  });

  test('strips .png extension', () => {
    expect(stripExtension('photo.png')).toBe('photo');
  });

  test('strips .jpeg extension', () => {
    expect(stripExtension('picture.jpeg')).toBe('picture');
  });

  test('strips .PNG uppercase extension', () => {
    expect(stripExtension('IMAGE.PNG')).toBe('IMAGE');
  });

  test('handles double extensions (strips only last)', () => {
    expect(stripExtension('image.png.jpg')).toBe('image.png');
  });

  test('handles no extension', () => {
    expect(stripExtension('filename')).toBe('filename');
  });

  test('handles empty string', () => {
    expect(stripExtension('')).toBe('');
  });

  test('handles null', () => {
    expect(stripExtension(null)).toBe('');
  });

  test('handles undefined', () => {
    expect(stripExtension(undefined)).toBe('');
  });

  test('handles filename with dots', () => {
    expect(stripExtension('my.image.file.png')).toBe('my.image.file');
  });

  test('handles hidden files', () => {
    expect(stripExtension('.gitignore')).toBe('.gitignore');
  });
});

describe('ensurePngExtension', () => {
  test('returns unchanged if already .png', () => {
    expect(ensurePngExtension('image.png')).toBe('image.png');
  });

  test('returns unchanged if already .PNG (uppercase)', () => {
    expect(ensurePngExtension('image.PNG')).toBe('image.PNG');
  });

  test('replaces .jpg with .png', () => {
    expect(ensurePngExtension('photo.jpg')).toBe('photo.png');
  });

  test('replaces .jpeg with .png', () => {
    expect(ensurePngExtension('photo.jpeg')).toBe('photo.png');
  });

  test('adds .png if no extension', () => {
    expect(ensurePngExtension('filename')).toBe('filename.png');
  });

  test('fixes double extension (image.png.jpg)', () => {
    expect(ensurePngExtension('image.png.jpg')).toBe('image.png.png');
  });

  test('handles empty string', () => {
    expect(ensurePngExtension('')).toBe('.png');
  });

  test('handles null', () => {
    expect(ensurePngExtension(null)).toBe('.png');
  });
});

describe('buildMarkedImagePath', () => {
  test('builds correct path with all components', () => {
    const result = buildMarkedImagePath('user123', '1704067200000', 'photo.jpg');
    expect(result).toBe('marked-images/user123/1704067200000/photo.png');
  });

  test('strips existing extension before adding .png', () => {
    const result = buildMarkedImagePath('user1', '12345', 'image.png');
    expect(result).toBe('marked-images/user1/12345/image.png');
  });

  test('handles filename with no extension', () => {
    const result = buildMarkedImagePath('user1', '12345', 'myimage');
    expect(result).toBe('marked-images/user1/12345/myimage.png');
  });

  test('handles complex filename', () => {
    const result = buildMarkedImagePath('abc', '999', 'my.complex.file.jpeg');
    expect(result).toBe('marked-images/abc/999/my.complex.file.png');
  });
});

describe('buildDetectingImagePath', () => {
  test('builds correct path', () => {
    const result = buildDetectingImagePath('user123', 'item456');
    expect(result).toBe('detecting-images/user123/item456');
  });
});

describe('buildTempPath', () => {
  test('builds path with filename', () => {
    const result = buildTempPath('task123', 'image.png');
    expect(result).toBe('/tmp/task123/image.png');
  });

  test('builds path without filename', () => {
    const result = buildTempPath('task123');
    expect(result).toBe('/tmp/task123');
  });

  test('builds path with empty filename', () => {
    const result = buildTempPath('task123', '');
    expect(result).toBe('/tmp/task123');
  });
});
