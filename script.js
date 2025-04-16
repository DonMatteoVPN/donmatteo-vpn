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

// Функция для управления раскрывающимися тарифами
function initTariffAccordion() {
    const categories = document.querySelectorAll('.tariff-category');
    
    // При загрузке показываем первую категорию
    const firstCategory = categories[0];
    const firstGrid = firstCategory.nextElementSibling;
    firstCategory.classList.add('active');
    firstGrid.classList.add('active');

    categories.forEach(category => {
        category.addEventListener('click', () => {
            const grid = category.nextElementSibling;
            
            // Если категория уже активна, ничего не делаем
            if (category.classList.contains('active')) {
                return;
            }

            // Закрываем все остальные категории
            categories.forEach(otherCategory => {
                if (otherCategory !== category) {
                    otherCategory.classList.remove('active');
                    otherCategory.nextElementSibling.classList.remove('active');
                }
            });

            // Открываем выбранную категорию
            category.classList.add('active');
            grid.classList.add('active');
        });
    });
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

// Инициализация при загрузке страницы
document.addEventListener('DOMContentLoaded', () => {
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
});

// Оптимизированный обработчик прокрутки
let scrollTimeout;
window.addEventListener('scroll', () => {
    if (scrollTimeout) {
        window.cancelAnimationFrame(scrollTimeout);
    }
    scrollTimeout = window.requestAnimationFrame(handleScrollAnimations);
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