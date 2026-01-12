const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TindartNFT", function () {
  let tindart;
  let owner, platform, artist, buyer, other;

  const LicenseType = {
    Display: 0,
    Commercial: 1,
    Transfer: 2
  };

  // Sample data
  const tokenUri = "ipfs://QmSampleMetadataHash";
  const imageHash = ethers.keccak256(ethers.toUtf8Bytes("sample-image-data"));
  const licenseHash = ethers.keccak256(ethers.toUtf8Bytes("sample-license-data"));
  const encryptedBlobUri = "ipfs://QmEncryptedBlobHash";

  beforeEach(async function () {
    [owner, platform, artist, buyer, other] = await ethers.getSigners();

    const TindartNFT = await ethers.getContractFactory("TindartNFT");
    tindart = await TindartNFT.deploy(platform.address);
    await tindart.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      expect(await tindart.name()).to.equal("Tindart");
      expect(await tindart.symbol()).to.equal("TIND");
    });

    it("Should set the platform wallet", async function () {
      expect(await tindart.platformWallet()).to.equal(platform.address);
    });

    it("Should start with zero supply", async function () {
      expect(await tindart.totalSupply()).to.equal(0);
    });
  });

  describe("Minting", function () {
    it("Should mint a token with Display license", async function () {
      const tx = await tindart.connect(artist).mint(
        artist.address,
        tokenUri,
        LicenseType.Display,
        imageHash,
        licenseHash,
        encryptedBlobUri
      );

      await expect(tx)
        .to.emit(tindart, "Minted")
        .withArgs(0, artist.address, LicenseType.Display, imageHash);

      expect(await tindart.ownerOf(0)).to.equal(artist.address);
      expect(await tindart.totalSupply()).to.equal(1);
    });

    it("Should mint a token with Commercial license", async function () {
      await tindart.connect(artist).mint(
        artist.address,
        tokenUri,
        LicenseType.Commercial,
        imageHash,
        licenseHash,
        encryptedBlobUri
      );

      const data = await tindart.getTokenData(0);
      expect(data.licenseType).to.equal(LicenseType.Commercial);
    });

    it("Should mint a token with Transfer license", async function () {
      await tindart.connect(artist).mint(
        artist.address,
        tokenUri,
        LicenseType.Transfer,
        imageHash,
        licenseHash,
        encryptedBlobUri
      );

      const data = await tindart.getTokenData(0);
      expect(data.licenseType).to.equal(LicenseType.Transfer);
    });

    it("Should store correct token data", async function () {
      await tindart.connect(artist).mint(
        artist.address,
        tokenUri,
        LicenseType.Commercial,
        imageHash,
        licenseHash,
        encryptedBlobUri
      );

      const data = await tindart.getTokenData(0);
      expect(data.creator).to.equal(artist.address);
      expect(data.currentOwner).to.equal(artist.address);
      expect(data.imageHash).to.equal(imageHash);
      expect(data.licenseHash).to.equal(licenseHash);
      expect(data.encryptedBlobUri).to.equal(encryptedBlobUri);
      expect(data.uri).to.equal(tokenUri);
    });

    it("Should prevent duplicate image hashes", async function () {
      await tindart.connect(artist).mint(
        artist.address,
        tokenUri,
        LicenseType.Display,
        imageHash,
        licenseHash,
        encryptedBlobUri
      );

      await expect(
        tindart.connect(other).mint(
          other.address,
          "ipfs://different",
          LicenseType.Display,
          imageHash, // Same image hash
          licenseHash,
          encryptedBlobUri
        )
      ).to.be.revertedWithCustomError(tindart, "ImageAlreadyRegistered");
    });

    it("Should set royalty for creator", async function () {
      await tindart.connect(artist).mint(
        artist.address,
        tokenUri,
        LicenseType.Display,
        imageHash,
        licenseHash,
        encryptedBlobUri
      );

      const salePrice = ethers.parseEther("1");
      const [recipient, amount] = await tindart.royaltyInfo(0, salePrice);

      expect(recipient).to.equal(artist.address);
      expect(amount).to.equal(salePrice * 250n / 10000n); // 2.5%
    });
  });

  describe("Marketplace - Listing", function () {
    beforeEach(async function () {
      await tindart.connect(artist).mint(
        artist.address,
        tokenUri,
        LicenseType.Display,
        imageHash,
        licenseHash,
        encryptedBlobUri
      );
    });

    it("Should allow owner to list token", async function () {
      const price = ethers.parseEther("0.5");

      await expect(tindart.connect(artist).list(0, price))
        .to.emit(tindart, "Listed")
        .withArgs(0, artist.address, price);

      const listing = await tindart.getListing(0);
      expect(listing.seller).to.equal(artist.address);
      expect(listing.price).to.equal(price);
      expect(listing.active).to.be.true;
    });

    it("Should not allow non-owner to list", async function () {
      await expect(
        tindart.connect(other).list(0, ethers.parseEther("1"))
      ).to.be.revertedWithCustomError(tindart, "NotTokenOwner");
    });

    it("Should not allow zero price", async function () {
      await expect(
        tindart.connect(artist).list(0, 0)
      ).to.be.revertedWithCustomError(tindart, "InvalidPrice");
    });

    it("Should not allow double listing", async function () {
      await tindart.connect(artist).list(0, ethers.parseEther("1"));

      await expect(
        tindart.connect(artist).list(0, ethers.parseEther("2"))
      ).to.be.revertedWithCustomError(tindart, "AlreadyListed");
    });

    it("Should allow owner to delist", async function () {
      await tindart.connect(artist).list(0, ethers.parseEther("1"));

      await expect(tindart.connect(artist).delist(0))
        .to.emit(tindart, "Delisted")
        .withArgs(0, artist.address);

      const listing = await tindart.getListing(0);
      expect(listing.active).to.be.false;
    });
  });

  describe("Marketplace - Buying", function () {
    const listPrice = ethers.parseEther("1");

    beforeEach(async function () {
      await tindart.connect(artist).mint(
        artist.address,
        tokenUri,
        LicenseType.Display,
        imageHash,
        licenseHash,
        encryptedBlobUri
      );
      await tindart.connect(artist).list(0, listPrice);
    });

    it("Should allow buying a listed token", async function () {
      const artistBalanceBefore = await ethers.provider.getBalance(artist.address);
      const platformBalanceBefore = await ethers.provider.getBalance(platform.address);

      await expect(tindart.connect(buyer).buy(0, { value: listPrice }))
        .to.emit(tindart, "Sold")
        .withArgs(0, artist.address, buyer.address, listPrice);

      // Check ownership transferred
      expect(await tindart.ownerOf(0)).to.equal(buyer.address);

      // Check listing cleared
      const listing = await tindart.getListing(0);
      expect(listing.active).to.be.false;

      // Check payments (2.5% platform fee, artist gets rest)
      const platformFee = listPrice * 250n / 10000n;
      const artistProceeds = listPrice - platformFee; // No royalty since artist is seller

      const artistBalanceAfter = await ethers.provider.getBalance(artist.address);
      const platformBalanceAfter = await ethers.provider.getBalance(platform.address);

      expect(platformBalanceAfter - platformBalanceBefore).to.equal(platformFee);
      expect(artistBalanceAfter - artistBalanceBefore).to.equal(artistProceeds);
    });

    it("Should pay royalty on secondary sales", async function () {
      // First sale: artist -> buyer
      await tindart.connect(buyer).buy(0, { value: listPrice });

      // Buyer relists
      const resalePrice = ethers.parseEther("2");
      await tindart.connect(buyer).list(0, resalePrice);

      // Second sale: buyer -> other
      const artistBalanceBefore = await ethers.provider.getBalance(artist.address);

      await tindart.connect(other).buy(0, { value: resalePrice });

      // Artist should receive 2.5% royalty
      const royalty = resalePrice * 250n / 10000n;
      const artistBalanceAfter = await ethers.provider.getBalance(artist.address);

      expect(artistBalanceAfter - artistBalanceBefore).to.equal(royalty);
    });

    it("Should not allow buying unlisted token", async function () {
      await tindart.connect(artist).delist(0);

      await expect(
        tindart.connect(buyer).buy(0, { value: listPrice })
      ).to.be.revertedWithCustomError(tindart, "NotListed");
    });

    it("Should not allow insufficient payment", async function () {
      await expect(
        tindart.connect(buyer).buy(0, { value: listPrice / 2n })
      ).to.be.revertedWithCustomError(tindart, "InsufficientPayment");
    });

    it("Should not allow buying own token", async function () {
      await expect(
        tindart.connect(artist).buy(0, { value: listPrice })
      ).to.be.revertedWithCustomError(tindart, "CannotBuyOwnToken");
    });

    it("Should refund excess payment", async function () {
      const excessAmount = ethers.parseEther("0.5");
      const totalPayment = listPrice + excessAmount;

      const buyerBalanceBefore = await ethers.provider.getBalance(buyer.address);

      const tx = await tindart.connect(buyer).buy(0, { value: totalPayment });
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      const buyerBalanceAfter = await ethers.provider.getBalance(buyer.address);

      // Buyer should only be charged listPrice + gas (excess refunded)
      const actualSpent = buyerBalanceBefore - buyerBalanceAfter - gasUsed;
      expect(actualSpent).to.be.closeTo(listPrice, ethers.parseEther("0.001"));
    });

    it("Should auto-delist on manual transfer", async function () {
      // Transfer outside marketplace should delist
      await tindart.connect(artist).transferFrom(artist.address, buyer.address, 0);

      const listing = await tindart.getListing(0);
      expect(listing.active).to.be.false;
    });
  });

  describe("View Functions", function () {
    beforeEach(async function () {
      await tindart.connect(artist).mint(
        artist.address,
        tokenUri,
        LicenseType.Commercial,
        imageHash,
        licenseHash,
        encryptedBlobUri
      );
    });

    it("Should return correct token URI", async function () {
      expect(await tindart.tokenURI(0)).to.equal(tokenUri);
    });

    it("Should check if image is registered", async function () {
      expect(await tindart.isImageRegistered(imageHash)).to.be.true;

      const unregisteredHash = ethers.keccak256(ethers.toUtf8Bytes("other"));
      expect(await tindart.isImageRegistered(unregisteredHash)).to.be.false;
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to change platform wallet", async function () {
      await tindart.connect(owner).setPlatformWallet(other.address);
      expect(await tindart.platformWallet()).to.equal(other.address);
    });

    it("Should not allow non-owner to change platform wallet", async function () {
      await expect(
        tindart.connect(other).setPlatformWallet(other.address)
      ).to.be.revertedWithCustomError(tindart, "OwnableUnauthorizedAccount");
    });
  });
});
