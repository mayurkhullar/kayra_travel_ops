const {
  pick,
  intBetween,
  chance,
  sample,
  addDays,
  addHours,
  isoDate,
  makeId,
  calcAgeAtDate,
  ageCategoryFor,
  uniqueEmail,
  phone,
} = require('./helpers');

const COLLECTIONS = [
  'users',
  'traveller_accounts',
  'groups',
  'travellers',
  'traveller_requests',
  'documents',
  'flights',
  'flight_segments',
  'hotels',
  'rooms',
  'tasks',
  'notifications',
  'activity_logs',
  'password_reset_requests',
];

const FIRST_NAMES = ['Aarav', 'Vihaan', 'Ishaan', 'Aanya', 'Diya', 'Mira', 'Riya', 'Kabir', 'Aditya', 'Sana', 'Neha', 'Rohan', 'Tanvi', 'Kunal', 'Anaya', 'Pooja'];
const LAST_NAMES = ['Sharma', 'Patel', 'Iyer', 'Nair', 'Singh', 'Gupta', 'Reddy', 'Jain', 'Khan', 'Mehta', 'Das', 'Kulkarni'];
const DESTINATIONS = {
  domestic: ['Goa', 'Jaipur', 'Kochi', 'Varanasi', 'Rishikesh'],
  international: ['Dubai', 'Singapore', 'Bangkok', 'Bali', 'Istanbul'],
};
const AIRPORTS = {
  Goa: ['DEL', 'GOI'],
  Jaipur: ['BLR', 'JAI'],
  Kochi: ['BOM', 'COK'],
  Varanasi: ['DEL', 'VNS'],
  Rishikesh: ['DEL', 'DED'],
  Dubai: ['BOM', 'DXB'],
  Singapore: ['MAA', 'SIN'],
  Bangkok: ['CCU', 'BKK'],
  Bali: ['DEL', 'DPS'],
  Istanbul: ['BOM', 'IST'],
};

function fullName() {
  return `${pick(FIRST_NAMES)} ${pick(LAST_NAMES)}`;
}

function buildUsers(now) {
  const users = [];
  const superAdmin = {
    id: makeId('user'),
    name: 'System Super Admin',
    role: 'super_admin',
    email: 'super.admin@example.com',
    phone: phone(),
    isActive: true,
    teamLeaderId: null,
    createdAt: addDays(now, -200),
  };
  users.push(superAdmin);

  const managers = Array.from({ length: 2 }).map((_, idx) => ({
    id: makeId('user'),
    name: `Manager ${idx + 1} ${pick(LAST_NAMES)}`,
    role: 'manager',
    email: `manager${idx + 1}@example.com`,
    phone: phone(),
    isActive: true,
    teamLeaderId: null,
    createdAt: addDays(now, -180 + idx),
  }));

  const teamLeaders = Array.from({ length: 3 }).map((_, idx) => ({
    id: makeId('user'),
    name: `Team Leader ${idx + 1} ${pick(LAST_NAMES)}`,
    role: 'team_leader',
    email: `team.leader${idx + 1}@example.com`,
    phone: phone(),
    isActive: true,
    teamLeaderId: null,
    createdAt: addDays(now, -160 + idx),
  }));

  const agents = Array.from({ length: 8 }).map((_, idx) => {
    const tl = teamLeaders[idx % teamLeaders.length];
    return {
      id: makeId('user'),
      name: `Agent ${idx + 1} ${pick(LAST_NAMES)}`,
      role: 'agent',
      email: `agent${idx + 1}@example.com`,
      phone: phone(),
      isActive: !chance(0.1),
      teamLeaderId: tl.id,
      createdAt: addDays(now, -120 + idx),
    };
  });

  users.push(...managers, ...teamLeaders, ...agents);
  return { users, superAdmin, managers, teamLeaders, agents };
}

function buildGroups(usersCtx, now) {
  const statuses = ['draft', 'active', 'travel_in_progress', 'completed', 'archived', 'cancelled'];
  const groups = [];
  const totalGroups = intBetween(10, 12);

  for (let i = 0; i < totalGroups; i += 1) {
    const groupType = i % 3 === 0 ? 'domestic' : 'international';
    const destination = pick(DESTINATIONS[groupType]);
    const depOffset = intBetween(-35, 80);
    const departureDate = addDays(now, depOffset);
    const arrivalDate = addDays(departureDate, intBetween(3, 8));
    const teamLeader = pick(usersCtx.teamLeaders);
    const agentIds = sample(usersCtx.agents.map((a) => a.id), intBetween(2, 4));
    const status = depOffset < -20 ? 'completed' : depOffset < -2 ? 'travel_in_progress' : pick(statuses);

    groups.push({
      id: makeId('grp'),
      name: `${destination} ${groupType === 'domestic' ? 'Pilgrim' : 'Leisure'} Group ${i + 1}`,
      destination,
      departureDate: isoDate(departureDate),
      arrivalDate: isoDate(arrivalDate),
      groupType,
      status,
      teamLeaderId: teamLeader.id,
      agentIds,
      travellerLinkEnabled: chance(0.85),
      travellerLinkPath: `/join/${destination.toLowerCase()}-${i + 1}`,
      passportValidityDays: groupType === 'international' ? pick([90, 120, 180]) : 0,
      branding: {
        logoUrl: `https://placehold.co/160x160?text=${encodeURIComponent(destination)}`,
        bannerUrl: `https://placehold.co/900x240?text=${encodeURIComponent(destination + ' Trip')}`,
        accentColor: pick(['#0E7490', '#7C3AED', '#059669', '#EA580C']),
      },
      createdBy: pick([usersCtx.superAdmin.id, ...usersCtx.managers.map((m) => m.id)]),
      createdAt: addDays(departureDate, -intBetween(40, 130)),
    });
  }

  return groups;
}

function buildTravellerAccountsAndTravellers(groups, now) {
  const travellerAccounts = [];
  const travellers = [];
  const travellersByGroup = new Map();
  const linkedFamilies = new Map();
  const totalTarget = intBetween(110, 145);
  let remainingTarget = totalTarget;

  groups.forEach((group, idx) => {
    const groupsLeft = groups.length - idx;
    const minForThisGroup = Math.max(8, Math.floor(remainingTarget / groupsLeft) - 2);
    const maxForThisGroup = Math.max(minForThisGroup, Math.floor(remainingTarget / groupsLeft) + 2);
    const perGroupTarget = idx === groups.length - 1 ? remainingTarget : intBetween(minForThisGroup, maxForThisGroup);
    const groupTravellers = [];
    let created = 0;

    while (created < perGroupTarget) {
      const accountName = fullName();
      const accountId = makeId('acct');
      const familySize = Math.min(intBetween(1, 4), perGroupTarget - created);

      const account = {
        id: accountId,
        fullName: accountName,
        phone: phone(),
        email: uniqueEmail(accountName, 'acct'),
        isActive: !chance(0.05),
        groupIds: [group.id],
        createdAt: addDays(now, -intBetween(2, 140)),
      };

      if (idx === 0 && travellerAccounts.length > 0 && chance(0.3)) {
        const reused = travellerAccounts[0];
        if (!reused.groupIds.includes(group.id)) reused.groupIds.push(group.id);
        account.id = reused.id;
        account.fullName = reused.fullName;
        account.phone = reused.phone;
        account.email = reused.email;
      } else {
        travellerAccounts.push(account);
      }

      const primaryId = makeId('trav');
      const primaryName = account.fullName;
      const birthYear = intBetween(1970, 2000);
      const dobPrimary = `${birthYear}-${String(intBetween(1, 12)).padStart(2, '0')}-${String(intBetween(1, 28)).padStart(2, '0')}`;
      const ageAtDeparture = calcAgeAtDate(dobPrimary, group.departureDate);
      const primaryTraveller = {
        id: primaryId,
        accountId: account.id,
        groupId: group.id,
        travellerType: 'primary',
        linkedPrimaryTravellerId: null,
        fullName: primaryName,
        phone: account.phone,
        email: account.email,
        dateOfBirth: dobPrimary,
        ageAtDeparture,
        ageCategory: ageCategoryFor(ageAtDeparture),
        status: pick(['submitted', 'under_review', 'approved', 'incomplete']),
        passportValidityStatus: group.groupType === 'domestic' ? 'not_applicable' : pick(['valid', 'valid', 'warning', 'invalid']),
        roomAssignmentId: null,
        flightAssignmentIds: [],
        createdAt: addDays(now, -intBetween(1, 90)),
      };
      travellers.push(primaryTraveller);
      groupTravellers.push(primaryTraveller);
      linkedFamilies.set(primaryId, [primaryId]);

      for (let i = 1; i < familySize; i += 1) {
        const type = i === 1 ? 'companion' : 'additional';
        const personName = fullName();
        const y = chance(0.15) ? intBetween(2015, 2025) : chance(0.2) ? intBetween(2008, 2014) : intBetween(1975, 2004);
        const dob = `${y}-${String(intBetween(1, 12)).padStart(2, '0')}-${String(intBetween(1, 28)).padStart(2, '0')}`;
        const age = calcAgeAtDate(dob, group.departureDate);
        const trav = {
          id: makeId('trav'),
          accountId: account.id,
          groupId: group.id,
          travellerType: type,
          linkedPrimaryTravellerId: primaryId,
          fullName: personName,
          phone: account.phone,
          email: uniqueEmail(personName),
          dateOfBirth: dob,
          ageAtDeparture: age,
          ageCategory: ageCategoryFor(age),
          status: pick(['submitted', 'under_review', 'approved', 'approved', 'incomplete', 'rejected']),
          passportValidityStatus: group.groupType === 'domestic' ? 'not_applicable' : pick(['valid', 'valid', 'warning', 'invalid']),
          roomAssignmentId: null,
          flightAssignmentIds: [],
          createdAt: addDays(now, -intBetween(1, 90)),
        };
        travellers.push(trav);
        groupTravellers.push(trav);
        linkedFamilies.get(primaryId).push(trav.id);
      }
      created += familySize;
    }

    travellersByGroup.set(group.id, groupTravellers);
    remainingTarget -= perGroupTarget;
  });

  return { travellerAccounts, travellers, travellersByGroup, linkedFamilies };
}

function buildFlightsAndSegments(groups, travellersByGroup, now) {
  const flights = [];
  const flightSegments = [];

  groups.forEach((group) => {
    const groupTravellers = travellersByGroup.get(group.id) || [];
    const flightCount = chance(0.4) ? 2 : 1;
    for (let i = 0; i < flightCount; i += 1) {
      const flightId = makeId('flt');
      const assignCount = intBetween(Math.max(4, Math.floor(groupTravellers.length * 0.35)), Math.max(5, Math.floor(groupTravellers.length * 0.8)));
      const assignedTravellers = sample(groupTravellers.map((t) => t.id), assignCount);
      const [depAirport, arrAirport] = AIRPORTS[group.destination] || ['DEL', 'BOM'];
      const departureDate = addHours(new Date(`${group.departureDate}T04:00:00.000Z`), i * 3);
      const arrivalDate = addHours(departureDate, intBetween(2, 6));

      flights.push({
        id: flightId,
        groupId: group.id,
        title: `${group.destination} ${i === 0 ? 'Outbound' : 'Return/Alternate'} Flight`,
        pnr: `${String.fromCharCode(65 + intBetween(0, 25))}${String.fromCharCode(65 + intBetween(0, 25))}${intBetween(100000, 999999)}`,
        status: pick(['scheduled', 'rescheduled', 'ticketed']),
        travellerIds: assignedTravellers,
        createdAt: addDays(now, -intBetween(1, 60)),
      });

      const segments = chance(0.35) ? 2 : 1;
      for (let s = 1; s <= segments; s += 1) {
        const segDep = addHours(departureDate, (s - 1) * 3);
        const segArr = addHours(segDep, 2);
        flightSegments.push({
          id: makeId('seg'),
          flightId,
          groupId: group.id,
          airline: pick(['IndiGo', 'Air India', 'Vistara', 'Emirates', 'Singapore Airlines', 'Thai Airways']),
          flightNumber: `${pick(['AI', '6E', 'UK', 'EK', 'SQ', 'TG'])}${intBetween(100, 9999)}`,
          departureAirport: s === 1 ? depAirport : 'CCU',
          arrivalAirport: s === segments ? arrAirport : 'CCU',
          departureDateTime: segDep.toISOString(),
          arrivalDateTime: segArr.toISOString(),
          segmentOrder: s,
          createdAt: addDays(now, -intBetween(1, 60)),
        });
      }

      assignedTravellers.forEach((travId) => {
        const traveller = groupTravellers.find((t) => t.id === travId);
        if (traveller) traveller.flightAssignmentIds.push(flightId);
      });
    }
  });

  return { flights, flightSegments };
}

function buildHotelsAndRooms(groups, travellersByGroup, linkedFamilies, now) {
  const hotels = [];
  const rooms = [];

  groups.forEach((group) => {
    const groupTravellers = travellersByGroup.get(group.id) || [];
    const hotel = {
      id: makeId('htl'),
      groupId: group.id,
      hotelName: `${group.destination} ${pick(['Grand', 'Suites', 'Regency', 'Residency'])}`,
      city: group.destination,
      checkInDate: group.departureDate,
      checkOutDate: group.arrivalDate,
      createdAt: addDays(now, -intBetween(1, 50)),
    };
    hotels.push(hotel);

    const unassigned = [...groupTravellers];
    let roomIndex = 1;
    while (unassigned.length) {
      const base = unassigned.shift();
      const familyIds = base.travellerType === 'primary' ? linkedFamilies.get(base.id) || [base.id] : [base.id];
      const familyMembers = familyIds
        .map((id) => groupTravellers.find((t) => t.id === id))
        .filter(Boolean)
        .filter((t) => unassigned.some((u) => u.id === t.id) || t.id === base.id);

      const capacity = pick([2, 3, 4]);
      let roomTravellers = [base.id];
      for (let i = 0; i < familyMembers.length && roomTravellers.length < capacity; i += 1) {
        if (!roomTravellers.includes(familyMembers[i].id) && chance(0.85)) {
          roomTravellers.push(familyMembers[i].id);
        }
      }

      if (chance(0.2) && unassigned.length) {
        roomTravellers.push(unassigned[0].id);
      }

      const room = {
        id: makeId('room'),
        hotelId: hotel.id,
        groupId: group.id,
        roomType: capacity >= 3 ? 'family' : pick(['double', 'twin']),
        capacity,
        travellerIds: roomTravellers.slice(0, capacity),
        roomNumber: chance(0.2) ? null : `${intBetween(1, 9)}${String(roomIndex).padStart(2, '0')}`,
        createdAt: addDays(now, -intBetween(1, 40)),
      };
      rooms.push(room);
      roomIndex += 1;

      room.travellerIds.forEach((travId) => {
        const idx = unassigned.findIndex((t) => t.id === travId);
        if (idx !== -1) unassigned.splice(idx, 1);
        const t = groupTravellers.find((traveller) => traveller.id === travId);
        if (t) t.roomAssignmentId = room.id;
      });
    }
  });

  return { hotels, rooms };
}

function buildTravellerRequests(groups, travellersByGroup, users, now) {
  const travellerRequests = [];
  groups.forEach((group) => {
    const primaryTravellers = (travellersByGroup.get(group.id) || []).filter((t) => t.travellerType === 'primary');
    sample(primaryTravellers, intBetween(1, Math.max(1, Math.floor(primaryTravellers.length / 2)))).forEach((trav) => {
      const requestedCount = intBetween(1, 3);
      const status = pick(['pending', 'partially_approved', 'approved', 'rejected', 'cancelled']);
      const approvedCount = status === 'approved' ? requestedCount : status === 'partially_approved' ? intBetween(1, requestedCount - 1 || 1) : 0;
      travellerRequests.push({
        id: makeId('treq'),
        groupId: group.id,
        primaryTravellerId: trav.id,
        requestedCount,
        approvedCount,
        status,
        reviewedBy: ['pending', 'cancelled'].includes(status) ? null : pick(users).id,
        reviewedAt: ['pending', 'cancelled'].includes(status) ? null : addDays(now, -intBetween(0, 20)),
        createdAt: addDays(now, -intBetween(1, 30)),
      });
    });
  });
  return travellerRequests;
}

function buildDocuments(travellers, groupsById, users, now) {
  const documents = [];
  const docTypes = ['aadhaar', 'pan', 'passport_front', 'passport_back'];
  travellers.forEach((trav) => {
    const group = groupsById.get(trav.groupId);
    const isInternational = group.groupType === 'international';
    const baseTypes = isInternational ? docTypes : ['aadhaar', 'pan'];

    baseTypes.forEach((docType) => {
      const status = pick(['uploaded', 'under_review', 'approved', 'rejected', 'reupload_required', 'superseded', 'not_uploaded']);
      const uploadedAt = ['not_uploaded'].includes(status) ? null : addDays(now, -intBetween(1, 45));
      const reviewedNeeded = ['approved', 'rejected', 'reupload_required', 'superseded'].includes(status);

      documents.push({
        id: makeId('doc'),
        groupId: trav.groupId,
        travellerId: trav.id,
        documentType: docType,
        storagePath: `mock/${trav.groupId}/${trav.id}/${docType}_v1.jpg`,
        version: intBetween(1, 3),
        isActive: !['superseded'].includes(status),
        status,
        uploadedBy: chance(0.75) ? trav.accountId : pick(users).id,
        uploadedAt,
        reviewedBy: reviewedNeeded ? pick(users).id : null,
        reviewedAt: reviewedNeeded ? addDays(now, -intBetween(0, 20)) : null,
      });
    });
  });
  return documents;
}

function buildTasks(groups, travellersByGroup, users, now) {
  const tasks = [];
  const issueTemplates = [
    ['Passport expiring soon', 'Collect renewed passport copy before ticketing.', 'high'],
    ['Aadhaar reupload required', 'Image is blurred; request clear reupload.', 'medium'],
    ['PNR confirmation follow-up', 'Airline changed timing, confirm revised itinerary.', 'medium'],
    ['Rooming list mismatch', 'Two companions need split-room exception handling.', 'low'],
    ['Final approval pending', 'Manager approval needed for traveller batch.', 'high'],
  ];
  groups.forEach((group) => {
    const groupTravellers = travellersByGroup.get(group.id) || [];
    const numTasks = intBetween(3, 6);
    for (let i = 0; i < numTasks; i += 1) {
      const [title, description, priority] = pick(issueTemplates);
      const linkedTraveller = chance(0.7) ? pick(groupTravellers) : null;
      tasks.push({
        id: makeId('task'),
        groupId: group.id,
        travellerId: linkedTraveller ? linkedTraveller.id : null,
        title,
        description,
        assignedToUserId: pick(users.filter((u) => ['team_leader', 'agent', 'manager'].includes(u.role))).id,
        priority,
        status: pick(['open', 'in_progress', 'done', 'cancelled']),
        dueDate: isoDate(addDays(now, intBetween(-2, 12))),
        createdAt: addDays(now, -intBetween(1, 20)),
      });
    }
  });
  return tasks;
}

function buildNotifications(users, travellerAccounts, groups, travellers, now) {
  const notifications = [];
  for (let i = 0; i < 40; i += 1) {
    const toUser = chance(0.65);
    const group = pick(groups);
    const traveller = pick(travellers.filter((t) => t.groupId === group.id));
    notifications.push({
      id: makeId('notif'),
      ...(toUser ? { recipientUserId: pick(users).id } : { recipientTravellerAccountId: pick(travellerAccounts).id }),
      title: pick(['Document review update', 'Task reassigned', 'Flight timing updated', 'Traveller request status changed']),
      body: pick([
        'Please review the latest traveller document status.',
        'A pending issue needs attention before departure.',
        'New status is available on your request.',
        'Kindly confirm room assignment updates.',
      ]),
      status: pick(['unread', 'read', 'archived']),
      type: pick(['workflow', 'document', 'flight', 'system']),
      relatedGroupId: group.id,
      relatedTravellerId: traveller ? traveller.id : null,
      createdAt: addDays(now, -intBetween(0, 15)),
    });
  }
  return notifications;
}

function buildActivityLogs(users, groups, travellers, tasks, documents, now) {
  const activityLogs = [];
  const actions = [
    ['updated_status', 'traveller'],
    ['approved_document', 'document'],
    ['reassigned_task', 'task'],
    ['created_group', 'group'],
  ];

  for (let i = 0; i < 80; i += 1) {
    const [action, targetType] = pick(actions);
    let target;
    if (targetType === 'traveller') target = pick(travellers);
    if (targetType === 'document') target = pick(documents);
    if (targetType === 'task') target = pick(tasks);
    if (targetType === 'group') target = pick(groups);
    activityLogs.push({
      id: makeId('log'),
      actorType: chance(0.8) ? 'user' : 'system',
      actorId: chance(0.8) ? pick(users).id : 'system_scheduler',
      action,
      targetType,
      targetId: target.id,
      groupId: target.groupId || (targetType === 'group' ? target.id : pick(groups).id),
      oldValue: chance(0.6) ? { status: pick(['draft', 'under_review', 'open']) } : null,
      newValue: { status: pick(['approved', 'in_progress', 'done', 'reupload_required']) },
      createdAt: addDays(now, -intBetween(0, 10)),
    });
  }
  return activityLogs;
}

function buildPasswordResetRequests(users, travellerAccounts, groups, now) {
  const requests = [];
  for (let i = 0; i < 24; i += 1) {
    const accountMode = chance(0.45);
    const status = pick(['pending', 'approved', 'rejected', 'cancelled']);
    requests.push({
      id: makeId('prr'),
      requestType: accountMode ? 'traveller_account' : 'user_account',
      requesterId: accountMode ? pick(travellerAccounts).id : pick(users).id,
      groupId: chance(0.65) ? pick(groups).id : null,
      status,
      reviewedBy: status === 'pending' ? null : pick(users).id,
      reviewedAt: status === 'pending' ? null : addDays(now, -intBetween(0, 8)),
      createdAt: addDays(now, -intBetween(0, 20)),
    });
  }
  return requests;
}

function generateSeedData() {
  const now = new Date();
  const usersCtx = buildUsers(now);
  const groups = buildGroups(usersCtx, now);
  const groupsById = new Map(groups.map((g) => [g.id, g]));
  const { travellerAccounts, travellers, travellersByGroup, linkedFamilies } = buildTravellerAccountsAndTravellers(groups, now);
  const { flights, flightSegments } = buildFlightsAndSegments(groups, travellersByGroup, now);
  const { hotels, rooms } = buildHotelsAndRooms(groups, travellersByGroup, linkedFamilies, now);
  const travellerRequests = buildTravellerRequests(groups, travellersByGroup, usersCtx.users, now);
  const documents = buildDocuments(travellers, groupsById, usersCtx.users, now);
  const tasks = buildTasks(groups, travellersByGroup, usersCtx.users, now);
  const notifications = buildNotifications(usersCtx.users, travellerAccounts, groups, travellers, now);
  const activityLogs = buildActivityLogs(usersCtx.users, groups, travellers, tasks, documents, now);
  const passwordResetRequests = buildPasswordResetRequests(usersCtx.users, travellerAccounts, groups, now);

  if (travellers.length < 100 || travellers.length > 150) {
    throw new Error(`Traveller volume out of bounds: ${travellers.length}. Expected 100-150.`);
  }

  return {
    users: usersCtx.users,
    traveller_accounts: travellerAccounts,
    groups,
    travellers,
    traveller_requests: travellerRequests,
    documents,
    flights,
    flight_segments: flightSegments,
    hotels,
    rooms,
    tasks,
    notifications,
    activity_logs: activityLogs,
    password_reset_requests: passwordResetRequests,
    _meta: { collections: COLLECTIONS },
  };
}

module.exports = {
  COLLECTIONS,
  generateSeedData,
};
