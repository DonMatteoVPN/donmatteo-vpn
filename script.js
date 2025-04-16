// Функция для проверки видимости элемента
function isElementInViewport(el) {
    const rect = el.getBoundingClientRect();
    return (
        rect.top >= 0 &&
        rect.left >= 0 &&
        rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
        rect.right <= (window.innerWidth || document.documentElement.clientWidth)
    );
}

// Улучшенная функция для анимации элементов при прокрутке
function handleScrollAnimations() {
    const animatedElements = document.querySelectorAll(
        '.feature-card, .price-card, .step, .faq-item'
    );

    animatedElements.forEach(element => {
        if (isElementInViewport(element)) {
            element.classList.add('animate__animated', 'animate__fadeInUp');
            element.style.animationDelay = '0.2s';
        }
    });

    // Анимация для баннера при прокрутке
    const banner = document.querySelector('.banner');
    if (banner && isElementInViewport(banner)) {
        banner.classList.add('animate__animated', 'animate__fadeIn');
        banner.style.animationDuration = '1.5s';
    }
}

// Улучшенная плавная прокрутка
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

// Анимация для hero секции при загрузке
document.addEventListener('DOMContentLoaded', () => {
    const heroContent = document.querySelector('.hero-content');
    if (heroContent) {
        heroContent.style.opacity = '0';
        setTimeout(() => {
            heroContent.style.transition = 'opacity 1s ease';
            heroContent.style.opacity = '1';
        }, 500);
    }

    // Инициализация анимаций
    handleScrollAnimations();
});

// Оптимизированный обработчик прокрутки
let scrollTimeout;
window.addEventListener('scroll', () => {
    if (scrollTimeout) {
        window.cancelAnimationFrame(scrollTimeout);
    }
    scrollTimeout = window.requestAnimationFrame(() => {
        handleScrollAnimations();
        
        // Подсветка активной секции при прокрутке
        const sections = document.querySelectorAll('section[id]');
        let currentSection = '';
        
        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.clientHeight;
            if (window.pageYOffset >= sectionTop - 60) {
                currentSection = section.getAttribute('id');
            }
        });

        document.querySelectorAll('.nav-links a').forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === `#${currentSection}`) {
                link.classList.add('active');
            }
        });
    });
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