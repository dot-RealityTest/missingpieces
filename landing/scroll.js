const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const progress = document.querySelector(".scroll-progress");
const revealTargets = [
  ".hero-content",
  ".section",
  ".download",
  ".site-footer",
].flatMap((selector) => [...document.querySelectorAll(selector)]);
const navLinks = [...document.querySelectorAll(".nav-links a")];
const sections = navLinks
  .map((link) => document.querySelector(link.hash))
  .filter(Boolean);

function updateProgress() {
  if (!progress) return;

  const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
  const amount = maxScroll <= 0 ? 0 : window.scrollY / maxScroll;
  progress.style.transform = `scaleX(${Math.min(Math.max(amount, 0), 1)})`;
}

function setActiveNav() {
  const atPageEnd = window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 96;
  const anchorOffset = window.innerHeight * 0.35;
  let activeSection = atPageEnd ? sections[sections.length - 1] : null;

  if (!atPageEnd) {
    for (const section of sections) {
      if (section.getBoundingClientRect().top <= anchorOffset) {
        activeSection = section;
      }
    }
  }

  for (const link of navLinks) {
    if (activeSection && link.hash === `#${activeSection.id}`) {
      link.setAttribute("aria-current", "page");
    } else {
      link.removeAttribute("aria-current");
    }
  }
}

if (reduceMotion) {
  revealTargets.forEach((target) => target.classList.add("is-visible"));
} else {
  const revealObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          revealObserver.unobserve(entry.target);
        }
      }
    },
    { rootMargin: "0px 0px -12% 0px", threshold: 0.12 },
  );

  revealTargets.forEach((target) => {
    target.classList.add("reveal-on-scroll");
    revealObserver.observe(target);
  });
}

for (const link of navLinks) {
  link.addEventListener("click", (event) => {
    const target = document.querySelector(link.hash);
    if (!target) return;

    event.preventDefault();
    target.scrollIntoView({
      behavior: reduceMotion ? "auto" : "smooth",
      block: "start",
    });
    history.pushState(null, "", link.hash);
  });
}

updateProgress();
setActiveNav();
window.addEventListener("scroll", () => {
  updateProgress();
  setActiveNav();
}, { passive: true });
window.addEventListener("resize", updateProgress);
