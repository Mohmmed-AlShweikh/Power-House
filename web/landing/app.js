(() => {
  const roles = {
    owner: {
      label: 'صاحب المولد', kicker: 'إدارة يومية، بصورة أوضح',
      title: ['تابع مولدك.', 'بدون تشتّت.'],
      description: 'حالة التشغيل والمشتركون والفواتير في نظرة عامة واحدة، مع أدوات متابعة القراءات والتحصيل.',
      points: ['إدارة المشتركين ومراجعة طلبات الانضمام', 'إسناد العدادات وإدارة جولات القراءة', 'مراجعة الدفعات ومتابعة الذمم والمصروفات']
    },
    consumer: {
      label: 'المشترك', kicker: 'تفاصيل اشتراكك، بين يديك',
      title: ['المعلومة أقرب.', 'والمتابعة أسهل.'],
      description: 'تعرف على حالة مولدك، وراجع فواتيرك واستهلاكك، وتابع طلباتك من مكان واحد.',
      points: ['اختيار المولد ومتابعة حالة طلب الانضمام', 'عرض الفواتير وتسجيل بيانات الدفع للمراجعة', 'متابعة الاستهلاك والتنبيهات والشكاوى']
    },
    reader: {
      label: 'قارئ العدادات', kicker: 'من العداد، إلى قراءة منظمة',
      title: ['عدّاداتك واضحة.', 'ومهمتك محددة.'],
      description: 'تجربة مخصصة للقارئ تعرض العدادات المسندة إليه في الجولة المفتوحة، دون قوائم الفواتير أو المالية.',
      points: ['قائمة العدادات المسندة إليك في الجولة', 'القراءة السابقة بجوار حقل القراءة الحالية', 'حفظ القراءة والانتقال إلى العداد التالي']
    },
    superadmin: {
      label: 'المشرف العام', kicker: 'إشراف على الطلبات وحالة المولدات',
      title: ['مراجعة واضحة.', 'وإدارة منظمة.'],
      description: 'راجع طلبات أصحاب المولدات، وتابع حالات المولدات واشتراكاتها من تجربة خاصة بالإشراف العام.',
      points: ['مراجعة طلبات تسجيل المولدات وقبولها أو رفضها', 'تعليق المولد أو إعادة تفعيله مع بيان السبب', 'تفعيل الاشتراك والتحكم بأهلية ظهور المولد']
    }
  };
  let role = 'owner';
  let theme = 'light';
  const tabs = [...document.querySelectorAll('[data-role]')];
  const themeButtons = [...document.querySelectorAll('[data-theme]')];
  const panel = document.getElementById('role-panel');
  const screen = document.getElementById('role-screen');
  const dialog = document.getElementById('screen-dialog');
  const shotButton = document.querySelector('.screenshot-button');
  const menuButton = document.querySelector('.menu-toggle');
  const menu = document.getElementById('mobile-nav');

  function render() {
    const data = roles[role];
    tabs.forEach(tab => {
      const selected = tab.dataset.role === role;
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
    });
    panel.setAttribute('aria-labelledby', `tab-${role}`);
    document.getElementById('role-kicker').textContent = data.kicker;
    const title = document.getElementById('role-title');
    title.replaceChildren(document.createTextNode(data.title[0]), document.createElement('br'), document.createTextNode(data.title[1]));
    document.getElementById('role-description').textContent = data.description;
    const points = document.getElementById('role-points');
    const check = points.querySelector('svg').cloneNode(true);
    points.replaceChildren(...data.points.map(text => {
      const li = document.createElement('li');
      li.append(check.cloneNode(true), document.createTextNode(text));
      return li;
    }));
    screen.src = `assets/${role}_${theme}.png`;
    screen.alt = `شاشة ${data.label} في الوضع ${theme === 'light' ? 'الفاتح' : 'الداكن'}`;
    shotButton.setAttribute('aria-label', `تكبير شاشة ${data.label}`);
    themeButtons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.theme === theme)));
  }

  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => { role = tab.dataset.role; render(); });
    tab.addEventListener('keydown', event => {
      let next;
      if (event.key === 'ArrowLeft') next = (index + 1) % tabs.length;
      if (event.key === 'ArrowRight') next = (index - 1 + tabs.length) % tabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = tabs.length - 1;
      if (next !== undefined) {
        event.preventDefault();
        role = tabs[next].dataset.role;
        render();
        tabs[next].focus();
      }
    });
  });
  themeButtons.forEach(button => button.addEventListener('click', () => { theme = button.dataset.theme; render(); }));

  menuButton.addEventListener('click', () => {
    const open = menuButton.getAttribute('aria-expanded') !== 'true';
    menuButton.setAttribute('aria-expanded', String(open));
    menuButton.setAttribute('aria-label', open ? 'إغلاق القائمة' : 'فتح القائمة');
    menu.hidden = !open;
  });
  function closeMenu() {
    menu.hidden = true;
    menuButton.setAttribute('aria-expanded', 'false');
    menuButton.setAttribute('aria-label', 'فتح القائمة');
  }
  menu.querySelectorAll('a').forEach(link => link.addEventListener('click', closeMenu));
  document.addEventListener('keydown', event => { if (event.key === 'Escape' && !menu.hidden) { closeMenu(); menuButton.focus(); } });
  matchMedia('(min-width: 901px)').addEventListener('change', event => { if (event.matches) closeMenu(); });

  shotButton.addEventListener('click', () => {
    dialog.querySelector('img').src = screen.src;
    dialog.querySelector('img').alt = screen.alt;
    document.getElementById('dialog-title').textContent = roles[role].label;
    dialog.showModal();
    document.body.classList.add('modal-open');
  });
  dialog.querySelector('button').addEventListener('click', () => dialog.close());
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  dialog.addEventListener('close', () => { document.body.classList.remove('modal-open'); shotButton.focus(); });

  // Only a configured public contact enables contact actions. No fake submission.
  const contact = window.PORTAL_CONTACT || {};
  let destination;
  if (/^\d{8,15}$/.test(contact.whatsapp || '')) {
    destination = `https://wa.me/${contact.whatsapp}?text=${encodeURIComponent('مرحباً، أود التعرف على بوابة المولدات وطلب عرض توضيحي.')}`;
  } else if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact.email || '')) {
    destination = `mailto:${contact.email}?subject=${encodeURIComponent('طلب عرض توضيحي — بوابة المولدات')}`;
  }
  if (destination) document.querySelectorAll('[data-contact]').forEach(link => {
    link.href = destination;
    link.hidden = false;
    if (destination.startsWith('https:')) { link.target = '_blank'; link.rel = 'noopener noreferrer'; }
  });
})();
