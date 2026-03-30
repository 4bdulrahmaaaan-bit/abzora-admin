import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectDir = path.resolve(__dirname, '..');
const rules = readFileSync(path.join(projectDir, 'database.rules.json'), 'utf8');

let testEnv;

const orderSeed = {
  userId: 'customer1',
  storeId: 'store1',
  totalAmount: 1999,
  status: 'Placed',
  paymentMethod: 'COD',
  timestamp: '2026-03-26T12:00:00.000Z',
  items: [{ productId: 'p1', productName: 'Kurta', quantity: 1, price: 1999 }],
  shippingLabel: 'Home',
  shippingAddress: 'T Nagar, Chennai',
  extraCharges: 0,
  subtotal: 1999,
  taxAmount: 0,
  platformCommission: 200,
  vendorEarnings: 1799,
  payoutStatus: 'Pending',
  riderId: null,
  trackingId: 'TRK-1',
  assignedDeliveryPartner: 'Unassigned',
  invoiceNumber: 'INV-1',
  orderType: 'marketplace',
  deliveryStatus: 'Placed',
  createdAt: '2026-03-26T12:00:00.000Z',
  updatedAt: '2026-03-26T12:00:00.000Z',
  deliveredAt: null,
  isConfirmed: false,
  isDelivered: false,
  payoutProcessed: false,
  paymentReference: null,
  idempotencyKey: 'idem-order1',
  isPaymentVerified: false,
};

async function seedBaseData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.database();
    await db.ref('users').set({
      customer1: { role: 'customer', isActive: true },
      customer2: { role: 'customer', isActive: true },
      vendor1: { role: 'vendor', isActive: true, storeId: 'store1' },
      vendor2: { role: 'vendor', isActive: true, storeId: 'store2' },
      rider1: { role: 'rider', isActive: true, riderApprovalStatus: 'approved' },
      rider2: { role: 'rider', isActive: true, riderApprovalStatus: 'approved' },
      admin1: { role: 'admin', isActive: true },
    });
    await db.ref('stores').set({
      store1: { ownerId: 'vendor1', isApproved: true, isActive: true, approvalStatus: 'approved' },
      store2: { ownerId: 'vendor2', isApproved: true, isActive: true, approvalStatus: 'approved' },
    });
    await db.ref('orders').set({
      order1: { ...orderSeed, riderId: 'rider1', deliveryStatus: 'Assigned' },
      order2: { ...orderSeed, userId: 'customer2', storeId: 'store2', trackingId: 'TRK-2', invoiceNumber: 'INV-2' },
    });
    await db.ref('payouts').set({
      payout1: { storeId: 'store1', status: 'Processed', amount: 1799, createdAt: '2026-03-26T12:00:00.000Z' },
      payout2: { storeId: 'store2', status: 'Processed', amount: 2500, createdAt: '2026-03-26T12:00:00.000Z' },
    });
    await db.ref('notifications').set({
      n1: { id: 'n1', audienceRole: 'customer', userId: 'customer1', timestamp: '2026-03-26T12:00:00.000Z' },
      n2: { id: 'n2', audienceRole: 'vendor', storeId: 'store1', timestamp: '2026-03-26T12:00:00.000Z' },
      n3: { id: 'n3', audienceRole: 'rider', userId: 'rider1', timestamp: '2026-03-26T12:00:00.000Z' },
      n4: { id: 'n4', audienceRole: 'admin', timestamp: '2026-03-26T12:00:00.000Z' },
      n5: { id: 'n5', audienceRole: 'all', timestamp: '2026-03-26T12:00:00.000Z' },
    });
    await db.ref('measurements').set({
      customer1: {
        m1: { id: 'm1', userId: 'customer1', name: 'My Size', chest: 38, waist: 32 },
      },
      customer2: {
        m2: { id: 'm2', userId: 'customer2', name: 'Wedding Fit', chest: 40, waist: 34 },
      },
    });
    await db.ref('reviews').set({
      review1: {
        userId: 'customer1',
        userName: 'Abdul Rahman',
        targetId: 'store1',
        targetType: 'store',
        rating: 5,
        comment: 'Excellent tailoring.',
        createdAt: '2026-03-26T12:00:00.000Z',
      },
      review2: {
        userId: 'customer2',
        userName: 'Sara',
        targetId: 'store2',
        targetType: 'store',
        rating: 4,
        comment: 'Nice collection.',
        createdAt: '2026-03-26T12:00:00.000Z',
      },
    });
    await db.ref('wishlist').set({
      customer1: {
        p1: {
          productId: 'p1',
          storeId: 'store1',
          name: 'Premium Kurta',
          price: 2499,
          image: 'https://example.com/p1.jpg',
          addedAt: '2026-03-26T12:00:00.000Z',
        },
      },
      customer2: {
        p2: {
          productId: 'p2',
          storeId: 'store2',
          name: 'Wedding Sherwani',
          price: 5999,
          image: 'https://example.com/p2.jpg',
          addedAt: '2026-03-26T12:00:00.000Z',
        },
      },
    });
    await db.ref('disputes').set({
      dispute1: { id: 'dispute1', orderId: 'order1', userId: 'customer1', storeId: 'store1', status: 'Open' },
    });
    await db.ref('activityLogs').set({
      log1: {
        id: 'log1',
        actorId: 'vendor1',
        actorRole: 'vendor',
        action: 'save_store',
        targetType: 'store',
        targetId: 'store1',
        message: 'Saved store store1',
        timestamp: '2026-03-26T12:00:00.000Z',
      },
    });
    await db.ref('vendorRequests').set({
      'vendor-customer1': {
        id: 'vendor-customer1',
        userId: 'customer1',
        storeName: 'Thread Theory',
        ownerName: 'Abdul Rahman',
        phone: '9999999999',
        address: 'T Nagar, Chennai',
        city: 'Chennai',
        latitude: 13.04,
        longitude: 80.23,
        kyc: {
          ownerPhotoUrl: 'https://example.com/owner.jpg',
          storeImageUrl: 'https://example.com/store.jpg',
          aadhaarUrl: 'https://example.com/aadhaar.jpg',
          panUrl: 'https://example.com/pan.jpg',
        },
        status: 'pending',
        createdAt: '2026-03-26T12:00:00.000Z',
        updatedAt: '2026-03-26T12:00:00.000Z',
        rejectionReason: '',
      },
    });
    await db.ref('riderRequests').set({
      'rider-customer2': {
        id: 'rider-customer2',
        userId: 'customer2',
        name: 'Kabir',
        phone: '8888888888',
        vehicle: 'Bike',
        city: 'Bengaluru',
        kyc: {
          profilePhotoUrl: 'https://example.com/profile.jpg',
          aadhaarUrl: 'https://example.com/aadhaar-rider.jpg',
          licenseUrl: 'https://example.com/license.jpg',
        },
        status: 'pending',
        createdAt: '2026-03-26T12:00:00.000Z',
        updatedAt: '2026-03-26T12:00:00.000Z',
        rejectionReason: '',
      },
    });
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'abzora-rtdb-rules',
    database: {
      host: '127.0.0.1',
      port: 9000,
      rules,
    },
  });
});

test.beforeEach(async () => {
  await testEnv.clearDatabase();
  await seedBaseData();
});

test.after(async () => {
  await testEnv.cleanup();
});

test('customer can manage own address but not another customer address', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertSucceeds(
    customerDb.ref('users/customer1/addresses/address1').set({
      userId: 'customer1',
      name: 'Abdul Rahman',
      phone: '9999999999',
      addressLine: 'T Nagar',
      city: 'Chennai',
      state: 'Tamil Nadu',
      pincode: '600017',
      createdAt: '2026-03-26T12:00:00.000Z',
    }),
  );

  await assertFails(customerDb.ref('users/customer2/addresses/address1').get());
});

test('customer can create own order but cannot rewrite financial fields afterward', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertSucceeds(
    customerDb.ref('orders/order-new').set({
      ...orderSeed,
      userId: 'customer1',
      trackingId: 'TRK-NEW',
      invoiceNumber: 'INV-NEW',
      idempotencyKey: 'idem-order-new',
      createdAt: '2026-03-27T09:00:00.000Z',
      updatedAt: '2026-03-27T09:00:00.000Z',
    }),
  );

  await assertFails(
    customerDb.ref('orders/order1').update({
      totalAmount: 999,
      vendorEarnings: 999,
    }),
  );
});

test('identity mutation on existing orders is blocked', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertFails(
    customerDb.ref('orders/order1').update({
      userId: 'customer2',
    }),
  );

  await assertFails(
    customerDb.ref('orders/order1').update({
      storeId: 'store2',
    }),
  );
});

test('customer can access only own measurements', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertSucceeds(customerDb.ref('measurements/customer1/m1').get());
  await assertSucceeds(
    customerDb.ref('measurements/customer1/m3').set({
      id: 'm3',
      userId: 'customer1',
      name: 'Office Wear',
      chest: 39,
      waist: 33,
    }),
  );
  await assertFails(customerDb.ref('measurements/customer2/m2').get());
});

test('customer can manage only own wishlist', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertSucceeds(customerDb.ref('wishlist/customer1/p1').get());
  await assertSucceeds(
    customerDb.ref('wishlist/customer1/p3').set({
      productId: 'p3',
      storeId: 'store1',
      name: 'Linen Shirt',
      price: 1799,
      image: 'https://example.com/p3.jpg',
      addedAt: '2026-03-26T12:00:00.000Z',
    }),
  );
  await assertFails(customerDb.ref('wishlist/customer2/p2').get());
});

test('customer can create own idempotency and payment claims but cannot hijack another user claims', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();
  const otherCustomerDb = testEnv.authenticatedContext('customer2').database();

  await assertSucceeds(
    customerDb.ref('idempotencyClaims/customer1/claim-1').set({
      idempotencyKey: 'claim-1',
      orderId: 'order-new',
      createdAt: '2026-03-27T09:05:00.000Z',
    }),
  );

  await assertSucceeds(
    customerDb.ref('paymentClaims/pay-1').set({
      userId: 'customer1',
      paymentReference: 'pay-1',
      createdAt: '2026-03-27T09:05:00.000Z',
    }),
  );

  await assertFails(
    otherCustomerDb.ref('paymentClaims/pay-1').update({
      userId: 'customer2',
      orderId: 'order-evil',
    }),
  );
});

test('customer can submit own vendor and rider KYC requests but cannot submit for another user', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();
  const otherCustomerDb = testEnv.authenticatedContext('customer2').database();

  await assertSucceeds(
    customerDb.ref('vendorRequests/vendor-customer1').set({
      id: 'vendor-customer1',
      userId: 'customer1',
      storeName: 'Thread Theory',
      ownerName: 'Abdul Rahman',
      phone: '9999999999',
      address: 'T Nagar, Chennai',
      city: 'Chennai',
      latitude: 13.04,
      longitude: 80.23,
      kyc: {
        ownerPhotoUrl: 'https://example.com/owner.jpg',
        storeImageUrl: 'https://example.com/store.jpg',
        aadhaarUrl: 'https://example.com/aadhaar.jpg',
        panUrl: 'https://example.com/pan.jpg',
      },
      status: 'pending',
      createdAt: '2026-03-27T09:00:00.000Z',
      updatedAt: '2026-03-27T09:00:00.000Z',
      rejectionReason: '',
    }),
  );

  await assertFails(
    otherCustomerDb.ref('vendorRequests/vendor-customer1').set({
      id: 'vendor-customer1',
      userId: 'customer1',
      status: 'pending',
    }),
  );

  await assertSucceeds(
    otherCustomerDb.ref('riderRequests/rider-customer2').set({
      id: 'rider-customer2',
      userId: 'customer2',
      name: 'Kabir',
      phone: '8888888888',
      vehicle: 'Bike',
      city: 'Bengaluru',
      kyc: {
        profilePhotoUrl: 'https://example.com/profile.jpg',
        aadhaarUrl: 'https://example.com/aadhaar-rider.jpg',
        licenseUrl: 'https://example.com/license.jpg',
      },
      status: 'pending',
      createdAt: '2026-03-27T09:00:00.000Z',
      updatedAt: '2026-03-27T09:00:00.000Z',
      rejectionReason: '',
    }),
  );
});

test('customer cannot self-approve KYC or edit approved requests', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertFails(
    customerDb.ref('vendorRequests/vendor-customer1').update({
      status: 'approved',
    }),
  );

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.database().ref('vendorRequests/vendor-customer1').update({
      status: 'approved',
      updatedAt: '2026-03-27T10:00:00.000Z',
    });
  });

  await assertFails(
    customerDb.ref('vendorRequests/vendor-customer1').update({
      storeName: 'Changed After Approval',
      status: 'pending',
    }),
  );
});

test('admin can approve or reject vendor and rider requests', async () => {
  const adminDb = testEnv.authenticatedContext('admin1').database();

  await assertSucceeds(
    adminDb.ref('vendorRequests/vendor-customer1').update({
      status: 'approved',
      updatedAt: '2026-03-27T10:00:00.000Z',
      rejectionReason: '',
    }),
  );

  await assertSucceeds(
    adminDb.ref('riderRequests/rider-customer2').update({
      status: 'rejected',
      updatedAt: '2026-03-27T10:05:00.000Z',
      rejectionReason: 'License image is blurry',
    }),
  );
});

test('customer can cancel own order without changing protected fields', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertSucceeds(
    customerDb.ref('orders/order1').update({
      ...orderSeed,
      riderId: 'rider1',
      deliveryStatus: 'Cancelled',
      status: 'Cancelled',
      trackingId: 'TRK-1',
      assignedDeliveryPartner: 'Unassigned',
      invoiceNumber: 'INV-1',
      orderType: 'marketplace',
    }),
  );
});

test('vendor can write only products for own store, including legacy store_id payloads', async () => {
  const vendorDb = testEnv.authenticatedContext('vendor1').database();

  await assertSucceeds(
    vendorDb.ref('products/p1').set({
      name: 'Premium Kurta',
      storeId: 'store1',
      price: 2499,
      category: 'Men',
      isActive: true,
      createdAt: '2026-03-26T12:00:00.000Z',
    }),
  );

  await assertSucceeds(
    vendorDb.ref('products/p2').set({
      name: 'Legacy Sherwani',
      store_id: 'store1',
      price: 5999,
      category: 'Wedding',
      isActive: true,
      createdAt: '2026-03-26T12:00:00.000Z',
    }),
  );

  await assertFails(
    vendorDb.ref('products/p3').set({
      name: 'Cross Store Product',
      storeId: 'store2',
      price: 1999,
      category: 'Men',
      isActive: true,
      createdAt: '2026-03-26T12:00:00.000Z',
    }),
  );
});

test('vendor can only read payouts for own store', async () => {
  const vendorDb = testEnv.authenticatedContext('vendor1').database();

  await assertSucceeds(vendorDb.ref('payouts/payout1').get());
  await assertFails(vendorDb.ref('payouts/payout2').get());
});

test('vendor can update allowed store fields but cannot touch restricted store fields', async () => {
  const vendorDb = testEnv.authenticatedContext('vendor1').database();

  await assertSucceeds(
    vendorDb.ref('stores/store1').update({
      name: 'ABZORA Men Studio',
      description: 'Updated storefront copy',
      logoUrl: 'https://example.com/logo.jpg',
    }),
  );
  await assertFails(
    vendorDb.ref('stores/store1').update({
      latitude: 12.98,
      approvalStatus: 'approved',
      commissionRate: 0.2,
    }),
  );
  await assertFails(
    vendorDb.ref('stores/store2').update({
      name: 'Cross Store Edit',
    }),
  );
});

test('vendor order status transitions are limited and totals stay immutable', async () => {
  const vendorDb = testEnv.authenticatedContext('vendor1').database();

  await assertSucceeds(
    vendorDb.ref('orders/order1').update({
      status: 'Confirmed',
      deliveryStatus: 'Confirmed',
      isConfirmed: true,
      updatedAt: '2026-03-26T12:05:00.000Z',
    }),
  );

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.database().ref('orders/order1').update({
      status: 'Confirmed',
      deliveryStatus: 'Confirmed',
      isConfirmed: true,
      updatedAt: '2026-03-26T12:05:00.000Z',
    });
  });

  await assertSucceeds(
    vendorDb.ref('orders/order1').update({
      status: 'Packed',
      deliveryStatus: 'Packed',
      updatedAt: '2026-03-26T12:10:00.000Z',
    }),
  );

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.database().ref('orders/order1').update({
      status: 'Packed',
      deliveryStatus: 'Packed',
      updatedAt: '2026-03-26T12:10:00.000Z',
    });
  });

  await assertSucceeds(
    vendorDb.ref('orders/order1').update({
      status: 'Ready for pickup',
      deliveryStatus: 'Ready for pickup',
      updatedAt: '2026-03-26T12:15:00.000Z',
    }),
  );

  await assertFails(
    vendorDb.ref('orders/order1').update({
      status: 'Delivered',
      deliveryStatus: 'Delivered',
    }),
  );

  await assertFails(
    vendorDb.ref('orders/order1').update({
      status: 'Ready for pickup',
      deliveryStatus: 'Ready for pickup',
      totalAmount: 100,
    }),
  );

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.database().ref('orders/order1').update({
      status: 'Packed',
      deliveryStatus: 'Packed',
      updatedAt: '2026-03-26T12:20:00.000Z',
      isConfirmed: true,
    });
  });

  await assertFails(
    vendorDb.ref('orders/order1').update({
      status: 'Packed',
      deliveryStatus: 'Packed',
      updatedAt: '2026-03-26T12:25:00.000Z',
    }),
  );
});

test('vendor cannot assign rider-related fields directly', async () => {
  const vendorDb = testEnv.authenticatedContext('vendor1').database();

  await assertFails(
    vendorDb.ref('orders/order1').update({
      riderId: 'rider2',
      assignedDeliveryPartner: 'Rider Two',
    }),
  );
});

test('only assigned rider can move delivery status forward', async () => {
  const riderOneDb = testEnv.authenticatedContext('rider1').database();
  const riderTwoDb = testEnv.authenticatedContext('rider2').database();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.database().ref('orders/order1').update({
      status: 'Ready for pickup',
      deliveryStatus: 'Assigned',
      riderId: 'rider1',
      assignedDeliveryPartner: 'Rider One',
      updatedAt: '2026-03-26T12:00:00.000Z',
      isDelivered: false,
      payoutProcessed: false,
    });
  });

  await assertFails(
    riderTwoDb.ref('orders/order1').update({
      status: 'Picked up',
      deliveryStatus: 'Picked up',
      updatedAt: '2026-03-26T12:05:00.000Z',
    }),
  );

  await assertSucceeds(
    riderOneDb.ref('orders/order1').update({
      status: 'Picked up',
      deliveryStatus: 'Picked up',
      updatedAt: '2026-03-26T12:05:00.000Z',
    }),
  );
});

test('customer can manage only own reviews', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertSucceeds(customerDb.ref('reviews/review1').remove());
  await assertSucceeds(
    customerDb.ref('reviews/review3').set({
      userId: 'customer1',
      userName: 'Abdul Rahman',
      targetId: 'store1',
      targetType: 'store',
      rating: 5,
      comment: 'Loved the service.',
      createdAt: '2026-03-26T12:00:00.000Z',
    }),
  );
  await assertFails(customerDb.ref('reviews/review2').remove());
});

test('rider can only read assigned order and rider notifications', async () => {
  const riderDb = testEnv.authenticatedContext('rider1').database();

  await assertSucceeds(riderDb.ref('orders/order1').get());
  await assertFails(riderDb.ref('orders/order2').get());
  await assertSucceeds(riderDb.ref('notifications/n3').get());
  await assertFails(riderDb.ref('notifications/n2').get());
});

test('customer sees own and global notifications but not vendor notifications', async () => {
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertSucceeds(customerDb.ref('notifications/n1').get());
  await assertSucceeds(customerDb.ref('notifications/n5').get());
  await assertFails(customerDb.ref('notifications/n2').get());
});

test('vendor and rider can write activity logs but only admin can read them', async () => {
  const vendorDb = testEnv.authenticatedContext('vendor1').database();
  const riderDb = testEnv.authenticatedContext('rider1').database();
  const adminDb = testEnv.authenticatedContext('admin1').database();
  const customerDb = testEnv.authenticatedContext('customer1').database();

  await assertSucceeds(
    vendorDb.ref('activityLogs/log-vendor').set({
      id: 'log-vendor',
      actorId: 'vendor1',
      actorRole: 'vendor',
      action: 'update_product',
      targetType: 'product',
      targetId: 'p1',
      message: 'Updated product p1',
      timestamp: '2026-03-26T12:00:00.000Z',
    }),
  );
  await assertSucceeds(
    riderDb.ref('activityLogs/log-rider').set({
      id: 'log-rider',
      actorId: 'rider1',
      actorRole: 'rider',
      action: 'update_delivery_status',
      targetType: 'order',
      targetId: 'order1',
      message: 'Updated delivery status',
      timestamp: '2026-03-26T12:00:00.000Z',
    }),
  );
  await assertFails(
    customerDb.ref('activityLogs/log-customer').set({
      id: 'log-customer',
      actorId: 'customer1',
      actorRole: 'customer',
      action: 'read_order',
      targetType: 'order',
      targetId: 'order1',
      message: 'Attempted write',
      timestamp: '2026-03-26T12:00:00.000Z',
    }),
  );
  await assertFails(vendorDb.ref('activityLogs/log1').get());
  await assertSucceeds(adminDb.ref('activityLogs/log1').get());
});

test('admin can access disputes and admin notifications', async () => {
  const adminDb = testEnv.authenticatedContext('admin1').database();

  const disputeSnapshot = await assertSucceeds(adminDb.ref('disputes/dispute1').get());
  const notificationSnapshot = await assertSucceeds(adminDb.ref('notifications/n4').get());

  assert.equal(disputeSnapshot.exists(), true);
  assert.equal(notificationSnapshot.exists(), true);
});

test('admin can approve store and read global notifications', async () => {
  const adminDb = testEnv.authenticatedContext('admin1').database();

  await assertSucceeds(
    adminDb.ref('stores/store1').update({
      ownerId: 'vendor1',
      isApproved: true,
      isActive: true,
      approvalStatus: 'approved',
      isFeatured: true,
    }),
  );
  await assertSucceeds(adminDb.ref('notifications/n5').get());
});
