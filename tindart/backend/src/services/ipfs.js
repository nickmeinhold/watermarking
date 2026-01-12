/**
 * IPFS Service
 * Uses Pinata for pinning files to IPFS
 */

const { PinataSDK } = require('pinata-web3');

const PINATA_JWT = process.env.PINATA_JWT;
const PINATA_GATEWAY = process.env.PINATA_GATEWAY || 'gateway.pinata.cloud';

let pinata = null;

function getPinata() {
  if (!pinata) {
    if (!PINATA_JWT) {
      throw new Error('PINATA_JWT environment variable required');
    }
    pinata = new PinataSDK({
      pinataJwt: PINATA_JWT,
      pinataGateway: PINATA_GATEWAY
    });
  }
  return pinata;
}

/**
 * Upload a file to IPFS
 * @param {Buffer} data - File data
 * @param {string} filename - Filename for metadata
 * @returns {Promise<string>} - IPFS URI (ipfs://...)
 */
async function upload(data, filename) {
  const client = getPinata();

  // Create a File object from buffer
  const file = new File([data], filename, {
    type: getMimeType(filename)
  });

  const result = await client.upload.file(file);

  return `ipfs://${result.IpfsHash}`;
}

/**
 * Upload JSON metadata to IPFS
 * @param {Object} json - JSON object
 * @param {string} filename - Filename for metadata
 * @returns {Promise<string>} - IPFS URI
 */
async function uploadJson(json, filename) {
  const client = getPinata();

  const result = await client.upload.json(json, {
    metadata: {
      name: filename
    }
  });

  return `ipfs://${result.IpfsHash}`;
}

/**
 * Get gateway URL for an IPFS URI
 * @param {string} ipfsUri - IPFS URI (ipfs://...)
 * @returns {string} - HTTP gateway URL
 */
function getGatewayUrl(ipfsUri) {
  if (!ipfsUri.startsWith('ipfs://')) {
    return ipfsUri;
  }
  const hash = ipfsUri.replace('ipfs://', '');
  return `https://${PINATA_GATEWAY}/ipfs/${hash}`;
}

/**
 * Fetch content from IPFS
 * @param {string} ipfsUri - IPFS URI
 * @returns {Promise<Buffer>} - File contents
 */
async function fetch(ipfsUri) {
  const client = getPinata();
  const hash = ipfsUri.replace('ipfs://', '');

  const response = await client.gateways.get(hash);
  return Buffer.from(await response.arrayBuffer());
}

/**
 * Get MIME type from filename
 */
function getMimeType(filename) {
  const ext = filename.split('.').pop()?.toLowerCase();
  const types = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'json': 'application/json'
  };
  return types[ext] || 'application/octet-stream';
}

module.exports = {
  upload,
  uploadJson,
  getGatewayUrl,
  fetch
};
