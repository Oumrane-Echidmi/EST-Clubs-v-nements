/**
 * Demo data: makes the app look alive (realistic French clubs, events with many
 * registrations, announcements, notifications). Idempotent; run AFTER `db:seed`:
 *   npm run db:seed:demo
 * Development only. Uses SEED_PASSWORD for the extra demo students.
 */
import 'dotenv/config';
import { PrismaClient, Category, EventStatus } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import bcrypt from 'bcrypt';
import { createHash } from 'crypto';

const db = new PrismaClient({
  adapter: new PrismaPg({
    connectionString: process.env.DATABASE_URL,
    max: 10,
    connectionTimeoutMillis: 5000,
  }),
});
const id = (label: string) => {
  const hex = createHash('sha256')
    .update(`est-development-seed:${label}`)
    .digest('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
};
const hoursFromNow = (n: number) => new Date(Date.now() + n * 3600000);

const FIRST = [
  'Yassine',
  'Salma',
  'Mehdi',
  'Kenza',
  'Anas',
  'Imane',
  'Omar',
  'Hajar',
  'Reda',
  'Sara',
  'Ilyas',
  'Meryem',
  'Zakaria',
  'Nada',
  'Amine',
  'Lina',
  'Hamza',
  'Aya',
  'Badr',
  'Rania',
];
const LAST = [
  'Amrani',
  'Bennani',
  'Tazi',
  'El Idrissi',
  'Alaoui',
  'Berrada',
  'Chraibi',
  'Fassi',
  'Lahlou',
  'Ouazzani',
  'Benjelloun',
  'Saidi',
  'Naciri',
  'Kabbaj',
  'Zniber',
  'Mansouri',
];

async function main() {
  if (process.env.NODE_ENV === 'production')
    throw new Error('Demo seed is forbidden in production');
  const password = process.env.SEED_PASSWORD;
  if (!password) throw new Error('Set SEED_PASSWORD');
  const passwordHash = await bcrypt.hash(password, 12);

  // --- 170 demo students (enough distinct users to fill big events) -----------
  const students = Array.from({ length: 170 }, (_, i) => {
    const email = `demo.student${i + 1}@est.example.edu`;
    return {
      id: id(email),
      email,
      passwordHash,
      role: 'STUDENT' as const,
      firstName: FIRST[i % FIRST.length],
      lastName: LAST[Math.floor(i / FIRST.length) % LAST.length],
      studentId: `EST-D${String(i + 1).padStart(4, '0')}`,
    };
  });
  await db.user.createMany({ data: students, skipDuplicates: true });

  // --- clubs: give the 6 approved seed clubs their French identity ------------
  const rename: Record<string, { name: string; description: string }> = {
    'EST Robotics': {
      name: 'Robotique & Systèmes Embarqués',
      description:
        'Conception de robots autonomes, objets connectés IoT et drones. Ateliers Arduino, STM32 et ESP32 chaque semaine au FabLab.',
    },
    'EST Science': {
      name: 'Club Informatique & Cybersécurité',
      description:
        "Pôle d'excellence en développement logiciel, CTF éthique, audit réseau et ateliers Linux pour les futurs ingénieurs de l'EST.",
    },
    'EST Arts': {
      name: 'Théâtre & Expression Scénique',
      description:
        "Maîtrise du trac, prise de parole en public, techniques de stand-up, scénographie et création d'œuvres théâtrales originales.",
    },
    'EST Sports': {
      name: 'Sport & Outdoor EST',
      description:
        'Ligues internes de football, basketball, sorties trail et trekking dans la région du Souss, programmes de préparation physique.',
    },
    'EST Solidarity': {
      name: 'Solidarité & Humanitaire EST',
      description:
        "Caravanes médicales, collectes de dons, accompagnement scolaire en milieu rural et actions citoyennes tout au long de l'année.",
    },
    'EST Entrepreneurs': {
      name: 'Enactus EST',
      description:
        'Création de projets entrepreneuriaux à fort impact sociétal. Incubation, business model canvas, coaching et compétitions nationales.',
    },
  };
  for (const [old, v] of Object.entries(rename))
    await db.club.updateMany({ where: { id: id(old) }, data: v });

  const extraClubs = [
    {
      key: 'Club Photo & Cinéma',
      name: 'Photographie & Cinéma',
      description:
        'Formation au cadrage cinématographique, étalonnage DaVinci Resolve, réalisation de courts-métrages universitaires et archivage photo.',
      category: Category.CULTURE,
    },
    {
      key: 'Club Musique',
      name: 'Musique & Harmonie',
      description:
        'Pratique instrumentale collective (oud, violon, guitare, piano), chorale polyphonique et arrangements fusion marocaine / jazz.',
      category: Category.CULTURE,
    },
  ];
  for (const c of extraClubs) {
    await db.club.upsert({
      where: { id: id(c.key) },
      create: {
        id: id(c.key),
        name: c.name,
        description: c.description,
        category: c.category,
        status: 'APPROVED',
        isFeatured: true,
        contactEmail: 'bureau@est.example.edu',
      },
      update: { name: c.name, description: c.description },
    });
    await db.clubMember.upsert({
      where: {
        clubId_userId: {
          clubId: id(c.key),
          userId: id('clubadmin2@est.example.edu'),
        },
      },
      create: {
        clubId: id(c.key),
        userId: id('clubadmin2@est.example.edu'),
        role: 'ADMIN',
      },
      update: {},
    });
  }
  await db.club.updateMany({
    where: { status: 'APPROVED' },
    data: { isFeatured: true },
  });

  // members + followers so the member counters look real
  const clubIds = [
    ...Object.keys(rename).map(id),
    ...extraClubs.map((c) => id(c.key)),
  ];
  for (const [ci, clubId] of clubIds.entries()) {
    const n = 40 + ((ci * 37) % 90);
    await db.clubMember.createMany({
      data: students
        .slice(ci * 7, ci * 7 + n)
        .map((s) => ({ clubId, userId: s.id, role: 'MEMBER' as const })),
      skipDuplicates: true,
    });
    await db.clubFollow.createMany({
      data: students
        .slice(ci * 5, ci * 5 + n + 20)
        .map((s) => ({ clubId, userId: s.id })),
      skipDuplicates: true,
    });
  }

  // --- events ----------------------------------------------------------------
  type Demo = {
    key: string;
    club: string; // club key (old seed name or extra key)
    title: string;
    description: string;
    category: Category;
    location: string;
    startH: number; // hours from now
    durH: number;
    deadlineH: number; // hours before start
    capacity: number;
    registered: number;
    status?: EventStatus;
  };
  const events: Demo[] = [
    {
      key: 'd-hackathon',
      club: 'EST Science',
      title: 'Hackathon EST INNOV 2026',
      description:
        "48 heures pour concevoir une solution innovante avec des équipes mixtes de toutes les filières. Mentors, ateliers pitch, jury d'entreprises partenaires et nombreux lots à gagner.",
      category: 'TECHNOLOGY',
      location: 'Amphi Central EST',
      startH: 62,
      durH: 48,
      deadlineH: 2,
      capacity: 160,
      registered: 142,
    },
    {
      key: 'd-robotique',
      club: 'EST Robotics',
      title: 'Atelier Robotique & Drones',
      description:
        "Montage et programmation d'un mini-drone quadricoptère : moteurs brushless, contrôleur de vol et premier vol en salle. Matériel fourni.",
      category: 'SCIENCE',
      location: 'FabLab Bloc B',
      startH: 30,
      durH: 3,
      deadlineH: 3,
      capacity: 40,
      registered: 32,
    },
    {
      key: 'd-esport',
      club: 'EST Robotics',
      title: 'Tournoi E-Sport & FIFA Inter-Filières',
      description:
        'Tournoi 1v1 en élimination directe sur FIFA, avec finale commentée en direct au foyer. Inscription par équipes de filière.',
      category: 'TECHNOLOGY',
      location: 'Foyer des Étudiants',
      startH: 52,
      durH: 5,
      deadlineH: 6,
      capacity: 64,
      registered: 64,
    },
    {
      key: 'd-masterclass',
      club: 'EST Entrepreneurs',
      title: 'Masterclass Pitch & Startup',
      description:
        "Comment convaincre un investisseur en 5 minutes ? Retours d'expérience de fondateurs, simulation de pitch et feedback en direct.",
      category: 'ENTREPRENEURSHIP',
      location: 'Salle des Thèses EST',
      startH: 76,
      durH: 3,
      deadlineH: 4,
      capacity: 80,
      registered: 80,
    },
    {
      key: 'd-ctf',
      club: 'EST Science',
      title: 'Cyber Défense CTF Night',
      description:
        'Capture the flag de nuit : challenges web, cryptographie et forensic pour équipes de 3. Pizzas et boissons offertes aux participants.',
      category: 'TECHNOLOGY',
      location: 'Salle Informatique 3',
      startH: 100,
      durH: 8,
      deadlineH: 12,
      capacity: 90,
      registered: 58,
    },
    {
      key: 'd-sciences',
      club: 'EST Science',
      title: 'Journée Portes Ouvertes Sciences',
      description:
        'Démonstrations de laboratoire, expériences interactives et rencontres avec les enseignants-chercheurs. Ouvert aux lycéens de la région.',
      category: 'SCIENCE',
      location: 'Hall des Laboratoires',
      startH: 130,
      durH: 6,
      deadlineH: 24,
      capacity: 200,
      registered: 87,
    },
    {
      key: 'd-theatre',
      club: 'EST Arts',
      title: "Soirée Théâtre d'Improvisation",
      description:
        "Match d'improvisation entre équipes de filières : rires garantis, public participatif et mini-ateliers d'initiation avant le spectacle.",
      category: 'CULTURE',
      location: 'Amphi B',
      startH: 148,
      durH: 3,
      deadlineH: 6,
      capacity: 120,
      registered: 71,
    },
    {
      key: 'd-trail',
      club: 'EST Sports',
      title: "Randonnée Trail dans l'Atlas",
      description:
        'Sortie trail de 12 km dans la vallée du Souss avec transport en bus depuis le campus. Niveau intermédiaire, eau et collation fournies.',
      category: 'SPORTS',
      location: 'Départ Parking EST',
      startH: 170,
      durH: 7,
      deadlineH: 48,
      capacity: 45,
      registered: 38,
    },
    {
      key: 'd-collecte',
      club: 'EST Solidarity',
      title: 'Collecte de Fournitures Scolaires',
      description:
        'Grande collecte de cartables et fournitures pour les écoles rurales de la région. Venez avec vos dons ou donnez de votre temps au tri.',
      category: 'SOCIAL',
      location: "Esplanade de l'EST",
      startH: 200,
      durH: 5,
      deadlineH: 12,
      capacity: 150,
      registered: 44,
    },
    {
      key: 'd-concert',
      club: 'Club Musique',
      title: "Concert de Fin d'Année Universitaire",
      description:
        'Orchestre andalou, chorale et groupes étudiants sur scène. Soirée musicale ouverte à toute la communauté EST.',
      category: 'CULTURE',
      location: 'Grande Salle des Fêtes',
      startH: 240,
      durH: 4,
      deadlineH: 24,
      capacity: 300,
      registered: 126,
    },
    {
      key: 'd-photo',
      club: 'Club Photo & Cinéma',
      title: 'Photo Walk & Cadrage Cinéma',
      description:
        'Balade photo guidée en centre-ville au coucher du soleil : composition, lumière naturelle et prise de vue au gimbal.',
      category: 'CULTURE',
      location: "Corniche d'Agadir",
      startH: 120,
      durH: 3,
      deadlineH: 10,
      capacity: 30,
      registered: 21,
    },
    {
      key: 'd-ia',
      club: 'EST Science',
      title: 'Conférence IA & Avenir des Métiers',
      description:
        "Intelligence artificielle générative, impact sur l'emploi et opportunités pour les jeunes ingénieurs, avec des intervenants de l'industrie.",
      category: 'TECHNOLOGY',
      location: 'Amphi Central EST',
      startH: 280,
      durH: 2,
      deadlineH: 24,
      capacity: 250,
      registered: 95,
    },
    {
      key: 'd-past-1',
      club: 'EST Entrepreneurs',
      title: 'Startup Weekend EST — Édition Automne',
      description:
        'Du concept au prototype en un week-end. Terminé : retrouvez les projets lauréats sur la page du club.',
      category: 'ENTREPRENEURSHIP',
      location: 'Amphi Central EST',
      startH: -200,
      durH: 30,
      deadlineH: 24,
      capacity: 100,
      registered: 96,
    },
    {
      key: 'd-past-2',
      club: 'EST Sports',
      title: 'Tournoi de Basketball Inter-Écoles',
      description:
        'Finale remportée par la filière Génie Informatique. Merci à tous les participants !',
      category: 'SPORTS',
      location: 'Gymnase EST',
      startH: -120,
      durH: 6,
      deadlineH: 24,
      capacity: 80,
      registered: 74,
    },
  ];
  const admin = (n: number) => id(`clubadmin${n}@est.example.edu`);
  const demoStudentIds = students.map((s) => s.id);
  const mainStudent = id('student1@est.example.edu');
  for (const [i, e] of events.entries()) {
    const eventId = id(e.key);
    const start = hoursFromNow(e.startH);
    const data = {
      clubId: id(e.club),
      createdById: admin((i % 3) + 1),
      title: e.title,
      description: e.description,
      category: e.category,
      location: e.location,
      startsAt: start,
      endsAt: hoursFromNow(e.startH + e.durH),
      registrationDeadline: hoursFromNow(e.startH - e.deadlineH),
      capacity: e.capacity,
      status: (e.status ?? 'PUBLISHED') as EventStatus,
    };
    await db.event.upsert({
      where: { id: eventId },
      create: { id: eventId, ...data },
      update: data,
    });
    const past = e.startH < 0;
    // distinct users, rotating the window so events overlap in attendance
    const pool = demoStudentIds.slice((i * 11) % 40).concat(demoStudentIds);
    const who = Array.from(new Set(pool)).slice(0, e.registered);
    await db.registration.createMany({
      data: who.map((userId, j) => ({
        id: id(`reg:${e.key}:${j}`),
        userId,
        eventId,
        status: past ? ('ATTENDED' as const) : ('CONFIRMED' as const),
      })),
      skipDuplicates: true,
    });
  }
  // the main demo student is registered to a few upcoming events + one past one
  for (const key of ['d-robotique', 'd-theatre', 'd-concert', 'd-past-1']) {
    await db.registration.upsert({
      where: { userId_eventId: { userId: mainStudent, eventId: id(key) } },
      create: {
        id: id(`reg:main:${key}`),
        userId: mainStudent,
        eventId: id(key),
        status: key === 'd-past-1' ? 'ATTENDED' : 'CONFIRMED',
      },
      update: {},
    });
  }

  // --- announcements & notifications -----------------------------------------
  const ann = [
    {
      k: 'a1',
      club: null,
      title: 'Bienvenue sur EST Clubs & Événements',
      body: 'Découvrez les 8 clubs officiels du campus et réservez vos places en un clic.',
    },
    {
      k: 'a2',
      club: 'EST Science',
      title: 'Hackathon EST INNOV 2026 : inscriptions bientôt closes',
      body: 'Plus que quelques places, formez votre équipe dès maintenant !',
    },
    {
      k: 'a3',
      club: 'EST Arts',
      title: 'Auditions Théâtre : samedi 18h',
      body: 'Venez tenter votre chance pour la prochaine création du club.',
    },
    {
      k: 'a4',
      club: 'EST Solidarity',
      title: 'Appel aux bénévoles — Caravane Hiver',
      body: 'Logistique, tutorat et accueil : tous les profils sont les bienvenus.',
    },
    {
      k: 'a5',
      club: null,
      title: 'Règle de cumul inter-clubs',
      body: "Chaque étudiant de l'EST peut être membre actif dans 2 clubs maximum simultanément.",
    },
  ];
  for (const a of ann)
    await db.announcement.upsert({
      where: { id: id(`demo-announcement:${a.k}`) },
      create: {
        id: id(`demo-announcement:${a.k}`),
        title: a.title,
        body: a.body,
        clubId: a.club ? id(a.club) : null,
        authorId: id('superadmin@est.example.edu'),
      },
      update: { title: a.title, body: a.body },
    });
  const notifs = [
    [
      'REGISTRATION_CONFIRMED',
      'Inscription confirmée',
      'Votre place pour « Atelier Robotique & Drones » est réservée.',
      'd-robotique',
    ],
    [
      'NEW_EVENT',
      'Nouvel événement',
      "Le club Musique & Harmonie a publié « Concert de Fin d'Année ».",
      'd-concert',
    ],
    [
      'REMINDER_24H',
      'Rendez-vous demain',
      "« Soirée Théâtre d'Improvisation » commence dans 24 heures.",
      'd-theatre',
    ],
    [
      'EVENT_UPDATED',
      'Événement mis à jour',
      'La salle du Hackathon EST INNOV 2026 a changé : Amphi Central.',
      'd-hackathon',
    ],
    [
      'NEW_EVENT',
      'Nouvel événement',
      'Cyber Défense CTF Night : ouverture des inscriptions.',
      'd-ctf',
    ],
  ] as const;
  for (const [i, n] of notifs.entries()) {
    const dedupeKey = `demo-notification:${i}`;
    await db.notification.upsert({
      where: { userId_dedupeKey: { userId: mainStudent, dedupeKey } },
      create: {
        userId: mainStudent,
        eventId: id(n[3]),
        type: n[0],
        title: n[1],
        body: n[2],
        dedupeKey,
      },
      update: { title: n[1], body: n[2] },
    });
  }

  // --- French titles for the original English seed records ---------------------
  const frEvents: Record<string, [string, string]> = {
    'Pending workshop': [
      'Atelier IA Générative',
      "Initiation pratique aux modèles génératifs : prompts, outils et cas d'usage étudiants.",
    ],
    'Rejected proposal': [
      'Soirée Gaming Nocturne',
      'Proposition de soirée jeux vidéo ouverte à toutes les filières.',
    ],
    'Cancelled meetup': [
      'Rencontre Alumni EST',
      'Échanges avec les anciens diplômés sur les parcours et opportunités.',
    ],
    'Completed seminar': [
      'Séminaire Cloud & DevOps',
      'Retour sur les bonnes pratiques de déploiement continu et de conteneurisation.',
    ],
    'Ongoing hackathon': [
      'Hackathon Green Tech',
      "Défi de 24 heures autour de solutions numériques pour l'environnement.",
    ],
    'Full robotics workshop': [
      'Atelier Arduino Avancé',
      'Capteurs, moteurs et programmation embarquée : atelier pratique à places limitées.',
    ],
    'Closed registrations': [
      'Conférence Cybersécurité',
      'Menaces actuelles, bonnes pratiques et métiers de la cybersécurité.',
    ],
    'My upcoming event': [
      'Forum des Stages EST',
      'Rencontrez les entreprises partenaires et déposez vos candidatures de stage.',
    ],
    'My cancelled registration': [
      'Tournoi de Futsal Inter-Filières',
      'Tournoi par équipes de cinq : ambiance et fair-play garantis.',
    ],
    'Campus innovation day': [
      "Journée de l'Innovation Campus",
      'Projets étudiants, démonstrations et rencontres avec les startups de la région.',
    ],
    'Sports tournament': [
      'Tournoi de Handball Universitaire',
      'Compétition inter-écoles sur deux jours avec remise des trophées.',
    ],
    'Cultural evening': [
      'Soirée Culturelle Amazighe',
      'Musique, danse et gastronomie : célébrons la richesse de notre culture.',
    ],
    'Community volunteering': [
      'Journée Bénévolat & Solidarité',
      'Actions de terrain avec les associations locales : nettoyage, tutorat et distribution.',
    ],
    'Entrepreneurship bootcamp': [
      'Bootcamp Entrepreneuriat',
      'Trois jours pour transformer une idée en projet : business model, pitch et coaching.',
    ],
    'Science showcase': [
      'Salon des Sciences & Innovations',
      'Expositions de projets scientifiques et démonstrations en direct.',
    ],
  };
  for (const [old, [title, description]] of Object.entries(frEvents))
    await db.event.updateMany({
      where: { id: id(old) },
      data: { title, description },
    });
  const frAnn: Record<string, [string, string]> = {
    'announcement:0': [
      'Bienvenue sur EST Clubs & Événements',
      'Découvrez les clubs du campus et inscrivez-vous aux événements.',
    ],
    'announcement:1': [
      'Actualité du club Robotique',
      "Nouvelle session d'ateliers Arduino chaque mercredi au FabLab.",
    ],
    'announcement:2': [
      'Actualité du club Sciences',
      'Appel à projets pour le Salon des Sciences & Innovations.',
    ],
    'announcement:3': [
      'Actualité du club Théâtre',
      'Les répétitions de la nouvelle création commencent la semaine prochaine.',
    ],
  };
  for (const [key, [title, body]] of Object.entries(frAnn))
    await db.announcement.updateMany({
      where: { id: id(key) },
      data: { title, body },
    });
  await db.notification.updateMany({
    where: { dedupeKey: { startsWith: 'seed-notification:' } },
    data: {
      title: 'Votre événement campus',
      body: "Consultez les dernières informations de l'événement.",
    },
  });
  console.log(
    `Demo data ready: ${students.length} demo students, ${clubIds.length} French clubs, ${events.length} events with registrations.`,
  );
}
main()
  .catch((e) => {
    console.error(
      'Demo seed failed:',
      e instanceof Error ? e.message : 'error',
    );
    process.exitCode = 1;
  })
  .finally(() => db.$disconnect());
