// Petits plus pour le dashboard (aucune librairie) :
// 1) recherche instantanée dans les tableaux, 2) compteurs animés.
(function () {
    // <input data-filter="#id-du-tableau"> filtre les lignes selon ce qu'on tape
    document.querySelectorAll('input[data-filter]').forEach(function (input) {
        var table = document.querySelector(input.dataset.filter);
        if (!table) return;
        var rows = Array.prototype.slice.call(table.querySelectorAll('tbody tr'));
        var counter = document.querySelector('[data-count-for="' + input.dataset.filter + '"]');
        input.addEventListener('input', function () {
            var q = input.value.trim().toLowerCase();
            var shown = 0;
            rows.forEach(function (tr) {
                var ok = q === '' || tr.textContent.toLowerCase().indexOf(q) !== -1;
                tr.hidden = !ok;
                if (ok) shown++;
            });
            if (counter) counter.textContent = shown + ' résultat(s)';
        });
    });

    // <div class="value" data-count="1234"> : le nombre monte jusqu'à sa valeur
    var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    document.querySelectorAll('[data-count]').forEach(function (el) {
        var target = parseInt(el.dataset.count, 10);
        if (isNaN(target) || reduce || target < 2) return;
        var start = null;
        function fmt(n) { return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' '); }
        function step(ts) {
            if (start === null) start = ts;
            var p = Math.min(1, (ts - start) / 900);
            el.textContent = fmt(target * (1 - Math.pow(1 - p, 3)));
            if (p < 1) requestAnimationFrame(step);
        }
        requestAnimationFrame(step);
    });

    // Bouton clair / sombre (le choix est gardé dans le navigateur)
    var toggle = document.getElementById('themeToggle');
    if (toggle) {
        toggle.addEventListener('click', function () {
            var root = document.documentElement;
            var next = root.dataset.theme === 'light' ? 'dark' : 'light';
            root.dataset.theme = next;
            try { localStorage.setItem('nrp-theme', next); } catch (e) {}
        });
    }
})();
