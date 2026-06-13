import UIKit

final class PhotoDetailViewController: UIViewController {

    // MARK: - Data
    private var photo: PhotoDTO
    var onTitleSaved: ((PhotoDTO) -> Void)?

    // MARK: - UI

    private let fullImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode     = .scaleAspectFill
        iv.clipsToBounds   = true
        iv.backgroundColor = UIColor.systemGray5
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleTextView: UITextView = {
        let tv = UITextView()
        tv.font               = .systemFont(ofSize: 20, weight: .semibold)
        tv.textColor          = .label
        tv.backgroundColor    = UIColor.secondarySystemBackground
        tv.layer.cornerRadius = 12
        tv.layer.masksToBounds = true
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.textContainerInset = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        tv.textContainer.lineFragmentPadding = 0
        tv.isScrollEnabled    = false
        tv.returnKeyType      = .done
        tv.autocapitalizationType = .sentences
        return tv
    }()

    private lazy var saveButton: UIButton = {
        var config                       = UIButton.Configuration.filled()
        config.title                     = "Save"
        config.cornerStyle               = .large
        config.baseBackgroundColor       = .systemBlue
        config.baseForegroundColor       = .white
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr; a.font = UIFont.systemFont(ofSize: 17, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Init
    init(photo: PhotoDTO) {
        self.photo = photo
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Photo #\(photo.id)"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground

        setupLayout()
        titleTextView.text = photo.title
        titleTextView.delegate = self
        loadImage()

        // Dismiss keyboard on tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        // Keyboard avoidance
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(fullImageView)
        view.addSubview(titleTextView)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            // Image — top to safeArea, full width, 50% of screen height
            fullImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            fullImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fullImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fullImageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.50),

            // Title text view — full width with padding, below image
            titleTextView.topAnchor.constraint(equalTo: fullImageView.bottomAnchor, constant: 24),
            titleTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            titleTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),

            // Save button — full width, below text view
            saveButton.topAnchor.constraint(equalTo: titleTextView.bottomAnchor, constant: 20),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    // MARK: - Image Loading
    private func loadImage() {
        let urlString = photo.url
        if let cached = sharedImageCache.object(forKey: urlString as NSString) {
            fullImageView.image = cached; return
        }
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let image = UIImage(data: data) else { return }
            sharedImageCache.setObject(image, forKey: urlString as NSString, cost: data.count)
            DispatchQueue.main.async {
                UIView.transition(with: self.fullImageView, duration: 0.3,
                                  options: .transitionCrossDissolve) {
                    self.fullImageView.image = image
                }
            }
        }.resume()
    }

    // MARK: - Actions
    @objc private func saveTapped() {
        let newTitle = titleTextView.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !newTitle.isEmpty else {
            // Shake if empty
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values   = [-10, 10, -8, 8, -4, 4, 0]
            shake.duration = 0.35
            titleTextView.layer.add(shake, forKey: "shake")
            return
        }

        view.endEditing(true)

        photo = PhotoDTO(albumId: photo.albumId, id: photo.id,
                         title: newTitle, url: photo.url, thumbnailUrl: photo.thumbnailUrl)
        onTitleSaved?(photo)

        // Brief button feedback
        saveButton.configuration?.title = "Saved ✓"
        saveButton.configuration?.baseBackgroundColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.saveButton.configuration?.title = "Save"
            self?.saveButton.configuration?.baseBackgroundColor = .systemBlue
        }
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        UIView.animate(withDuration: 0.25) {
            self.view.transform = CGAffineTransform(translationX: 0, y: -frame.height / 3)
        }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        UIView.animate(withDuration: 0.25) { self.view.transform = .identity }
    }
}

// MARK: - UITextViewDelegate
extension PhotoDetailViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}
