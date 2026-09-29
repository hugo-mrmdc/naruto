<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

DashboardAuth::requireSuperAdmin();

$me = DashboardAuth::currentUser();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    DashboardAuth::checkCsrf();

    $db = Database::connection();
    $targetId = (int) ($_POST['user_id'] ?? 0);
    $action = (string) ($_POST['action'] ?? '');

    if ($targetId === $me['id']) {
        $flash = ['error', "Tu ne peux pas modifier ton propre compte depuis cette page."];
    } else {
        $stmt = $db->prepare('SELECT * FROM dashboard_users WHERE id = :id');
        $stmt->execute(['id' => $targetId]);
        $target = $stmt->fetch();

        if (!$target) {
            $flash = ['error', 'Utilisateur introuvable.'];
        } elseif ($action === 'approve') {
            $db->prepare('UPDATE dashboard_users SET status = "active", approved_at = NOW(), approved_by = :by WHERE id = :id')
                ->execute(['by' => $me['username'], 'id' => $targetId]);
            $flash = ['success', "Compte de {$target['username']} activé."];
        } elseif ($action === 'disable') {
            $activeSuperadmins = (int) $db->query("SELECT COUNT(*) FROM dashboard_users WHERE role = 'superadmin' AND status = 'active'")->fetchColumn();
            if ($target['role'] === 'superadmin' && $target['status'] === 'active' && $activeSuperadmins <= 1) {
                $flash = ['error', 'Impossible : ce serait le dernier super admin actif.'];
            } else {
                $db->prepare('UPDATE dashboard_users SET status = "disabled" WHERE id = :id')->execute(['id' => $targetId]);
                $flash = ['success', "Compte de {$target['username']} désactivé."];
            }
        } elseif ($action === 'promote') {
            $db->prepare("UPDATE dashboard_users SET role = 'superadmin' WHERE id = :id")->execute(['id' => $targetId]);
            $flash = ['success', "{$target['username']} est maintenant super admin."];
        } elseif ($action === 'demote') {
            $activeSuperadmins = (int) $db->query("SELECT COUNT(*) FROM dashboard_users WHERE role = 'superadmin' AND status = 'active'")->fetchColumn();
            if ($activeSuperadmins <= 1) {
                $flash = ['error', 'Impossible : ce serait le dernier super admin.'];
            } else {
                $db->prepare("UPDATE dashboard_users SET role = 'admin' WHERE id = :id")->execute(['id' => $targetId]);
                $flash = ['success', "{$target['username']} n'est plus super admin."];
            }
        } else {
            $flash = ['error', 'Action inconnue.'];
        }
    }
}

$users = db_try(static fn (PDO $db) => $db->query('SELECT * FROM dashboard_users ORDER BY status = "pending" DESC, created_at DESC')->fetchAll());

page_start('Comptes du dashboard');
?>

<?php if (isset($flash)): ?>
    <p style="color:<?= $flash[0] === 'success' ? 'var(--success)' : 'var(--danger)' ?>"><?= h($flash[1]) ?></p>
<?php endif; ?>

<div class="card">
    <?php if ($users === []): ?>
        <p class="empty">Aucun compte pour l'instant.</p>
    <?php else: ?>
    <table>
        <thead><tr><th>Utilisateur</th><th>Rôle</th><th>Statut</th><th>Créé le</th><th>Actions</th></tr></thead>
        <tbody>
        <?php foreach ($users as $u): ?>
            <tr>
                <td data-label="Utilisateur"><?= h($u['username']) ?><?= (int) $u['id'] === $me['id'] ? ' <span class="badge">toi</span>' : '' ?></td>
                <td data-label="Rôle"><span class="badge <?= $u['role'] === 'superadmin' ? 'accent' : '' ?>"><?= h($u['role']) ?></span></td>
                <td data-label="Statut">
                    <?php $cls = ['active' => 'success', 'pending' => 'warning', 'disabled' => 'danger'][$u['status']] ?? ''; ?>
                    <span class="badge <?= $cls ?>"><?= h($u['status']) ?></span>
                </td>
                <td data-label="Créé le"><?= h(fmt_date($u['created_at'])) ?></td>
                <td data-label="Actions" class="wrap">
                    <?php if ((int) $u['id'] === $me['id']): ?>
                        —
                    <?php else: ?>
                        <?php if ($u['status'] === 'pending'): ?>
                            <form method="post" style="display:inline">
                                <input type="hidden" name="csrf" value="<?= h(DashboardAuth::csrfToken()) ?>">
                                <input type="hidden" name="user_id" value="<?= (int) $u['id'] ?>">
                                <input type="hidden" name="action" value="approve">
                                <button type="submit" class="badge success" style="border:none;cursor:pointer">Activer</button>
                            </form>
                        <?php endif; ?>
                        <?php if ($u['status'] !== 'disabled'): ?>
                            <form method="post" style="display:inline">
                                <input type="hidden" name="csrf" value="<?= h(DashboardAuth::csrfToken()) ?>">
                                <input type="hidden" name="user_id" value="<?= (int) $u['id'] ?>">
                                <input type="hidden" name="action" value="disable">
                                <button type="submit" class="badge danger" style="border:none;cursor:pointer">Désactiver</button>
                            </form>
                        <?php endif; ?>
                        <?php if ($u['role'] === 'admin'): ?>
                            <form method="post" style="display:inline">
                                <input type="hidden" name="csrf" value="<?= h(DashboardAuth::csrfToken()) ?>">
                                <input type="hidden" name="user_id" value="<?= (int) $u['id'] ?>">
                                <input type="hidden" name="action" value="promote">
                                <button type="submit" class="badge" style="border:none;cursor:pointer">Passer super admin</button>
                            </form>
                        <?php else: ?>
                            <form method="post" style="display:inline">
                                <input type="hidden" name="csrf" value="<?= h(DashboardAuth::csrfToken()) ?>">
                                <input type="hidden" name="user_id" value="<?= (int) $u['id'] ?>">
                                <input type="hidden" name="action" value="demote">
                                <button type="submit" class="badge" style="border:none;cursor:pointer">Repasser admin</button>
                            </form>
                        <?php endif; ?>
                    <?php endif; ?>
                </td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>
</div>

<?php page_end(); ?>
