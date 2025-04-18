// Функция для проверки видимости элемента с учетом отступа
function isElementInViewport(el, offset = 0) {
    const rect = el.getBoundingClientRect();
    const windowHeight = window.innerHeight || document.documentElement.clientHeight;
    return rect.top <= windowHeight * (0.85 + offset);
}

// Функция для управления раскрывающимися тарифами
function initTariffAccordion() {
    const categories = document.querySelectorAll('.tariff-category');
    
    categories.forEach(category => {
        category.addEventListener('click', function() {
            const grid = this.nextElementSibling;
            const isExpanded = this.classList.contains('active');
            
            // Если категория активна, закрываем её
            if (isExpanded) {
                this.classList.remove('active');
                grid.style.maxHeight = '0';
                grid.classList.remove('active');
                return;
            }

            // Закрываем все остальные категории
            categories.forEach(otherCategory => {
                if (otherCategory !== this) {
                    otherCategory.classList.remove('active');
                    const otherGrid = otherCategory.nextElementSibling;
                    otherGrid.style.maxHeight = '0';
                    otherGrid.classList.remove('active');
                }
            });

            // Открываем выбранную категорию
            this.classList.add('active');
            grid.classList.add('active');
            grid.style.maxHeight = grid.scrollHeight + 'px';

            // Плавно скроллим к началу категории
            const yOffset = -80;
            const y = this.getBoundingClientRect().top + window.pageYOffset + yOffset;
            window.scrollTo({top: y, behavior: 'smooth'});
        });
    });
}

// Улучшенная функция для анимации элементов при прокрутке
function handleScrollAnimations() {
    const animatedElements = document.querySelectorAll(
        '.feature-card, .price-card, .step, .faq-item'
    );

    animatedElements.forEach(element => {
        if (isElementInViewport(element) && !element.classList.contains('animate__animated')) {
            element.classList.add('animate__animated', 'animate__fadeInUp');
            element.style.opacity = '1';
        }
    });

    // Анимация для баннера при прокрутке
    const banner = document.querySelector('.banner');
    if (banner && isElementInViewport(banner)) {
        banner.classList.add('animate__animated', 'animate__fadeIn');
        banner.style.animationDuration = '1.5s';
    }
}

// Улучшенная плавная прокрутка с учетом производительности
function smoothScroll(target, duration = 1000) {
    const targetPosition = target.getBoundingClientRect().top + window.pageYOffset;
    const startPosition = window.pageYOffset;
    const distance = targetPosition - startPosition;
    let startTime = null;

    function animation(currentTime) {
        if (startTime === null) startTime = currentTime;
        const timeElapsed = currentTime - startTime;
        const run = ease(timeElapsed, startPosition, distance, duration);
        window.scrollTo(0, run);
        if (timeElapsed < duration) requestAnimationFrame(animation);
    }

    function ease(t, b, c, d) {
        t /= d / 2;
        if (t < 1) return c / 2 * t * t + b;
        t--;
        return -c / 2 * (t * (t - 2) - 1) + b;
    }

    requestAnimationFrame(animation);
}

// Обновленная обработка навигационных ссылок
document.querySelectorAll('.nav-links a').forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        const href = link.getAttribute('href');
        if (href.startsWith('#')) {
            const target = document.querySelector(href);
            if (target) {
                smoothScroll(target);
                
                // Добавляем подсветку активной секции
                document.querySelectorAll('.nav-links a').forEach(l => l.classList.remove('active'));
                link.classList.add('active');
            }
        }
    });
});

// Оптимизированный обработчик прокрутки с debounce
let scrollTimeout;
window.addEventListener('scroll', () => {
    if (scrollTimeout) {
        window.cancelAnimationFrame(scrollTimeout);
    }
    scrollTimeout = window.requestAnimationFrame(handleScrollAnimations);
}, { passive: true });

// Управление навигацией
function initNavigation() {
    const header = document.querySelector('header');
    const menuToggle = document.querySelector('.menu-toggle');
    const navLinks = document.querySelector('.nav-links');
    const navLinksItems = document.querySelectorAll('.nav-links a');
    let lastScroll = 0;

    // Обработка скролла с debounce
    let scrollTimeout;
    window.addEventListener('scroll', () => {
        if (scrollTimeout) {
            window.cancelAnimationFrame(scrollTimeout);
        }
        scrollTimeout = window.requestAnimationFrame(() => {
            const currentScroll = window.pageYOffset;
            
            // Добавляем класс scrolled при прокрутке
            if (currentScroll > 50) {
                header.classList.add('scrolled');
            } else {
                header.classList.remove('scrolled');
            }

            lastScroll = currentScroll;
        });
    }, { passive: true });

    // Мобильное меню
    menuToggle.addEventListener('click', () => {
        navLinks.classList.toggle('active');
        menuToggle.querySelector('i').classList.toggle('fa-bars');
        menuToggle.querySelector('i').classList.toggle('fa-times');
    });

    // Закрытие меню при клике на ссылку
    navLinksItems.forEach(link => {
        link.addEventListener('click', () => {
            navLinks.classList.remove('active');
            menuToggle.querySelector('i').classList.add('fa-bars');
            menuToggle.querySelector('i').classList.remove('fa-times');
        });
    });

    // Плавная прокрутка к секциям
    navLinksItems.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const targetId = link.getAttribute('href');
            const targetSection = document.querySelector(targetId);
            const headerHeight = header.offsetHeight;

            if (targetSection) {
                const targetPosition = targetSection.offsetTop - headerHeight;
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });

    // Подсветка активного пункта меню при скролле
    function highlightActiveSection() {
        const sections = document.querySelectorAll('section[id]');
        const scrollPosition = window.pageYOffset + header.offsetHeight + 100;

        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.offsetHeight;
            const sectionId = section.getAttribute('id');
            const navLink = document.querySelector(`.nav-links a[href="#${sectionId}"]`);

            if (scrollPosition >= sectionTop && scrollPosition < sectionTop + sectionHeight) {
                navLinksItems.forEach(link => link.classList.remove('active'));
                navLink?.classList.add('active');
            }
        });
    }

    window.addEventListener('scroll', highlightActiveSection, { passive: true });
    highlightActiveSection();
}

// Инициализация при загрузке страницы
document.addEventListener('DOMContentLoaded', () => {
    initNavigation();
    initTariffAccordion();
    handleScrollAnimations();
    
    // Анимация для hero секции
    const heroContent = document.querySelector('.hero-content');
    if (heroContent) {
        heroContent.style.opacity = '0';
        setTimeout(() => {
            heroContent.style.transition = 'opacity 1s ease';
            heroContent.style.opacity = '1';
        }, 500);
    }

    // Открываем первую категорию по умолчанию
    const firstCategory = document.querySelector('.tariff-category');
    if (firstCategory) {
        setTimeout(() => {
            firstCategory.click();
        }, 500);
    }
});

// Отслеживание кликов по кнопкам для Google Analytics
document.querySelectorAll('.cta-button').forEach(button => {
    button.addEventListener('click', () => {
        const buttonText = button.textContent.trim();
        if (typeof gtag !== 'undefined') {
            gtag('event', 'click', {
                'event_category': 'CTA',
                'event_label': buttonText
            });
        }
    });
}); 