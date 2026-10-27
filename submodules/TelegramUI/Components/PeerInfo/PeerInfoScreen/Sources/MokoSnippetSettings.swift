import UIKit
import TelegramCore

// The editor currently stores plain text; existing formatting around a trigger is preserved.
enum MokoSnippetSettings {
    static func showAliases(presenter: UIViewController, accountId: Int64, isRussian: Bool) {
        let values = MokoQuickCommands.aliases(accountId: accountId)
        let list = values.keys.sorted().map { ".\($0) = \(values[$0] ?? "")" }.joined(separator: "\n")
        let help = isRussian ? "Команды: calc, id, snip, tag, note, archive, unarchive, mute, unmute, save. Пустая команда удаляет алиас." : "Commands: calc, id, snip, tag, note, archive, unarchive, mute, unmute, save. An empty command removes the alias."
        let alert = UIAlertController(title: isRussian ? "Алиасы команд" : "Command aliases", message: list.isEmpty ? help : "\(list)\n\n\(help)", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = isRussian ? "Алиас" : "Alias"
            field.autocapitalizationType = .none
        }
        alert.addTextField { field in
            field.placeholder = isRussian ? "Команда" : "Command"
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: isRussian ? "Отмена" : "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: isRussian ? "Сохранить" : "Save", style: .default, handler: { [weak alert, weak presenter] _ in
            let name = alert?.textFields?.first?.text ?? ""
            let target = alert?.textFields?.last?.text ?? ""
            if !MokoQuickCommands.saveAlias(name: name, target: target, accountId: accountId), let presenter {
                let error = UIAlertController(title: isRussian ? "Неверный алиас" : "Invalid alias", message: help, preferredStyle: .alert)
                error.addAction(UIAlertAction(title: "OK", style: .default))
                presenter.present(error, animated: true)
            }
        }))
        presenter.present(alert, animated: true)
    }

    static func show(presenter: UIViewController, accountId: Int64, isRussian: Bool) {
        let title = isRussian ? "Сниппеты mokaGram" : "mokaGram snippets"
        let text = isRussian ? "Введите ;имя в обычном текстовом сообщении, чтобы подставить сохранённый текст. Сниппеты хранятся на этом устройстве." : "Type ;name in an ordinary text message to insert saved text. Snippets are stored on this device."
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        let snippets = MokoSnippets.all(accountId: accountId)
        for name in snippets.keys.sorted() {
            alert.addAction(UIAlertAction(title: ";\(name)", style: .default, handler: { [weak presenter] _ in
                guard let presenter else { return }
                edit(presenter: presenter, accountId: accountId, isRussian: isRussian, name: name, text: snippets[name] ?? "", isNew: false)
            }))
        }
        alert.addAction(UIAlertAction(title: isRussian ? "Добавить" : "Add", style: .default, handler: { [weak presenter] _ in
            guard let presenter else { return }
            edit(presenter: presenter, accountId: accountId, isRussian: isRussian, name: "", text: "", isNew: true)
        }))
        alert.addAction(UIAlertAction(title: isRussian ? "Закрыть" : "Close", style: .cancel))
        presenter.present(alert, animated: true)
    }

    private static func edit(presenter: UIViewController, accountId: Int64, isRussian: Bool, name: String, text: String, isNew: Bool) {
        let alert = UIAlertController(title: isRussian ? "Редактировать сниппет" : "Edit snippet", message: isRussian ? "Имя: буквы, цифры или _. Пустой текст удалит сниппет." : "Name: letters, numbers or _. An empty text deletes the snippet.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = isRussian ? "Имя" : "Name"
            field.text = name
            field.autocapitalizationType = .none
            field.isEnabled = isNew
        }
        alert.addTextField { field in
            field.placeholder = isRussian ? "Текст" : "Text"
            field.text = text
        }
        alert.addAction(UIAlertAction(title: isRussian ? "Отмена" : "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: isRussian ? "Сохранить" : "Save", style: .default, handler: { [weak alert, weak presenter] _ in
            guard let presenter else { return }
            let newName = alert?.textFields?.first?.text ?? ""
            let newText = alert?.textFields?.last?.text ?? ""
            let normalizedName = newName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let alreadyExists = isNew && MokoSnippets.all(accountId: accountId)[normalizedName] != nil
            if alreadyExists || !MokoSnippets.save(name: newName, text: newText, accountId: accountId) {
                let message = alreadyExists ? (isRussian ? "Сниппет с таким именем уже существует." : "A snippet with this name already exists.") : (isRussian ? "Используйте от 1 до 24 букв, цифр или символов _." : "Use 1–24 letters, numbers or underscores.")
                let error = UIAlertController(title: isRussian ? "Не удалось сохранить" : "Could not save", message: message, preferredStyle: .alert)
                error.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak presenter] _ in
                    guard let presenter else { return }
                    edit(presenter: presenter, accountId: accountId, isRussian: isRussian, name: newName, text: newText, isNew: isNew)
                }))
                presenter.present(error, animated: true)
            }
        }))
        presenter.present(alert, animated: true)
    }
}
