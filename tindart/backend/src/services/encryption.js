/**
 * Encryption Service
 * Uses Google Cloud KMS for key management
 * Implements envelope encryption: KMS key encrypts per-image AES keys
 */

const { KeyManagementServiceClient } = require('@google-cloud/kms');
const crypto = require('crypto');

const PROJECT_ID = process.env.GCP_PROJECT_ID || 'tindart';
const LOCATION = process.env.KMS_LOCATION || 'global';
const KEY_RING = process.env.KMS_KEY_RING || 'tindart-keys';
const KEY_NAME = process.env.KMS_KEY_NAME || 'master-key';

// KMS client (lazy initialized)
let kmsClient = null;

function getKmsClient() {
  if (!kmsClient) {
    kmsClient = new KeyManagementServiceClient();
  }
  return kmsClient;
}

function getKeyPath() {
  return `projects/${PROJECT_ID}/locations/${LOCATION}/keyRings/${KEY_RING}/cryptoKeys/${KEY_NAME}`;
}

/**
 * Encrypt image data using envelope encryption
 * 1. Generate random AES-256 key
 * 2. Encrypt image with AES key
 * 3. Encrypt AES key with KMS master key
 * 4. Return encrypted image + encrypted key
 *
 * @param {Buffer} data - Data to encrypt
 * @param {string} keyId - Unique ID for this key (used for lookup)
 * @returns {Promise<{encryptedBuffer: Buffer, keyId: string}>}
 */
async function encrypt(data, keyId) {
  // Generate random AES-256 key and IV
  const aesKey = crypto.randomBytes(32);
  const iv = crypto.randomBytes(16);

  // Encrypt data with AES-256-GCM
  const cipher = crypto.createCipheriv('aes-256-gcm', aesKey, iv);
  const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
  const authTag = cipher.getAuthTag();

  // Encrypt the AES key with KMS
  const client = getKmsClient();
  const [encryptResponse] = await client.encrypt({
    name: getKeyPath(),
    plaintext: aesKey
  });
  const encryptedAesKey = encryptResponse.ciphertext;

  // Package everything together
  // Format: [version(1)] [iv(16)] [authTag(16)] [encryptedKeyLen(4)] [encryptedKey] [encryptedData]
  const encryptedKeyBuffer = Buffer.from(encryptedAesKey);
  const encryptedKeyLen = Buffer.alloc(4);
  encryptedKeyLen.writeUInt32BE(encryptedKeyBuffer.length);

  const encryptedBuffer = Buffer.concat([
    Buffer.from([0x01]), // Version byte
    iv,
    authTag,
    encryptedKeyLen,
    encryptedKeyBuffer,
    encrypted
  ]);

  return {
    encryptedBuffer,
    keyId
  };
}

/**
 * Decrypt image data
 * @param {Buffer} encryptedBuffer - Encrypted data from encrypt()
 * @returns {Promise<Buffer>} - Decrypted data
 */
async function decrypt(encryptedBuffer) {
  // Parse the encrypted package
  let offset = 0;

  const version = encryptedBuffer.readUInt8(offset);
  offset += 1;

  if (version !== 0x01) {
    throw new Error(`Unsupported encryption version: ${version}`);
  }

  const iv = encryptedBuffer.slice(offset, offset + 16);
  offset += 16;

  const authTag = encryptedBuffer.slice(offset, offset + 16);
  offset += 16;

  const encryptedKeyLen = encryptedBuffer.readUInt32BE(offset);
  offset += 4;

  const encryptedAesKey = encryptedBuffer.slice(offset, offset + encryptedKeyLen);
  offset += encryptedKeyLen;

  const encryptedData = encryptedBuffer.slice(offset);

  // Decrypt the AES key with KMS
  const client = getKmsClient();
  const [decryptResponse] = await client.decrypt({
    name: getKeyPath(),
    ciphertext: encryptedAesKey
  });
  const aesKey = Buffer.from(decryptResponse.plaintext);

  // Decrypt the data with AES
  const decipher = crypto.createDecipheriv('aes-256-gcm', aesKey, iv);
  decipher.setAuthTag(authTag);

  const decrypted = Buffer.concat([decipher.update(encryptedData), decipher.final()]);

  return decrypted;
}

/**
 * For development/testing without KMS
 * Uses a local key (NOT SECURE FOR PRODUCTION)
 */
const DEV_KEY = process.env.DEV_ENCRYPTION_KEY
  ? Buffer.from(process.env.DEV_ENCRYPTION_KEY, 'hex')
  : crypto.randomBytes(32);

async function encryptDev(data, keyId) {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-gcm', DEV_KEY, iv);
  const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
  const authTag = cipher.getAuthTag();

  // Simple format: [version(1)] [iv(16)] [authTag(16)] [data]
  const encryptedBuffer = Buffer.concat([
    Buffer.from([0x00]), // Version 0 = dev mode
    iv,
    authTag,
    encrypted
  ]);

  return { encryptedBuffer, keyId };
}

async function decryptDev(encryptedBuffer) {
  let offset = 0;

  const version = encryptedBuffer.readUInt8(offset);
  offset += 1;

  if (version !== 0x00) {
    throw new Error('Not a dev-mode encrypted file');
  }

  const iv = encryptedBuffer.slice(offset, offset + 16);
  offset += 16;

  const authTag = encryptedBuffer.slice(offset, offset + 16);
  offset += 16;

  const encryptedData = encryptedBuffer.slice(offset);

  const decipher = crypto.createDecipheriv('aes-256-gcm', DEV_KEY, iv);
  decipher.setAuthTag(authTag);

  return Buffer.concat([decipher.update(encryptedData), decipher.final()]);
}

// Export appropriate functions based on environment
const USE_KMS = process.env.USE_KMS === 'true';

module.exports = {
  encrypt: USE_KMS ? encrypt : encryptDev,
  decrypt: USE_KMS ? decrypt : decryptDev
};
