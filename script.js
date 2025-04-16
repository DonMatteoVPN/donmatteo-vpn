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

// Функция для анимации элементов при прокрутке
function handleScrollAnimations() {
    const animatedElements = document.querySelectorAll(
        '.feature-card, .price-card, .step, .faq-item'
    );

    animatedElements.forEach(element => {
        if (isElementInViewport(element)) {
            element.classList.add('animate__fadeInUp');
        }
    });
}

// Обработчик прокрутки с устранением дребезга
let scrollTimeout;
window.addEventListener('scroll', () => {
    if (scrollTimeout) {
        window.cancelAnimationFrame(scrollTimeout);
    }
    scrollTimeout = window.requestAnimationFrame(() => {
        handleScrollAnimations();
    });
});

// Инициализация анимаций при загрузке страницы
document.addEventListener('DOMContentLoaded', () => {
    handleScrollAnimations();
    
    // Анимация для hero секции
    const heroContent = document.querySelector('.hero-content');
    if (heroContent) {
        heroContent.classList.add('animate__fadeIn');
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

// Плавная прокрутка для навигационных ссылок
document.querySelectorAll('.nav-links a').forEach(link => {
    link.addEventListener('click', (e) => {
        const href = link.getAttribute('href');
        if (href.startsWith('#')) {
            e.preventDefault();
            const target = document.querySelector(href);
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        }
    });
}); 