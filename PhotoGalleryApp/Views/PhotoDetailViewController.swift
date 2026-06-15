import UIKit

final class PhotoDetailViewController: UIViewController {

    // MARK: - Data
    private var photo: PhotoDTO
    private let photoIndex: Int
    var onTitleSaved: ((PhotoDTO) -> Void)?
    var onPhotoDeleted: ((Int) -> Void)?
    /// Called when Core Data fails to persist the title change.
    var onSaveError: ((String) -> Void)?

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 20
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let fullImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode     = .scaleAspectFill
        iv.clipsToBounds   = true
        iv.backgroundColor = UIColor.systemGray5
        iv.layer.cornerRadius = 12
        iv.layer.masksToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    /// Placeholder shown when the full image cannot be downloaded.
    private let detailPlaceholderView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 56, weight: .light)
        let iv = UIImageView(image: UIImage(systemName: "photo", withConfiguration: config))
        iv.tintColor        = UIColor.systemGray3
        iv.contentMode      = .center
        iv.backgroundColor  = UIColor.systemGray5
        iv.layer.cornerRadius  = 12
        iv.layer.masksToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true   // only revealed on failure
        return iv
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text      = "Title"
        l.font      = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let titleTextView: UITextView = {
        let tv = UITextView()
        tv.font               = .systemFont(ofSize: 17, weight: .regular)
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
        config.title                     = "Save Title"
        config.image                     = UIImage(systemName: "checkmark")
        config.imagePadding              = 8
        config.cornerStyle               = .large
        config.baseBackgroundColor       = .systemBlue
        config.baseForegroundColor       = .white
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr; a.font = UIFont.systemFont(ofSize: 16, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var deleteButton: UIButton = {
        var config                       = UIButton.Configuration.filled()
        config.title                     = "Delete Photo"
        config.image                     = UIImage(systemName: "trash")
        config.imagePadding              = 8
        config.cornerStyle               = .large
        config.baseBackgroundColor       = UIColor.systemRed.withAlphaComponent(0.9)
        config.baseForegroundColor       = .white
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr; a.font = UIFont.systemFont(ofSize: 16, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Init
    init(photo: PhotoDTO, index: Int) {
        self.photo      = photo
        self.photoIndex = index
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Photo #\(photo.id)"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground

        // Nav bar trash button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(deleteTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemRed

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
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        // Image container (padded)
        let imageContainer = UIView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.addSubview(fullImageView)
        imageContainer.addSubview(detailPlaceholderView)   // sits on top, hidden by default
        imageContainer.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            fullImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            fullImageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor, constant: 20),
            fullImageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -20),
            fullImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            fullImageView.heightAnchor.constraint(equalToConstant: 280),

            // Placeholder perfectly overlays the image view
            detailPlaceholderView.topAnchor.constraint(equalTo: fullImageView.topAnchor),
            detailPlaceholderView.leadingAnchor.constraint(equalTo: fullImageView.leadingAnchor),
            detailPlaceholderView.trailingAnchor.constraint(equalTo: fullImageView.trailingAnchor),
            detailPlaceholderView.bottomAnchor.constraint(equalTo: fullImageView.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: fullImageView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: fullImageView.centerYAnchor)
        ])

        // Label + text view wrapper
        let titleSection = UIView()
        titleSection.translatesAutoresizingMaskIntoConstraints = false
        titleSection.addSubview(titleLabel)
        titleSection.addSubview(titleTextView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: titleSection.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleSection.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: titleSection.trailingAnchor, constant: -20),

            titleTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            titleTextView.leadingAnchor.constraint(equalTo: titleSection.leadingAnchor, constant: 20),
            titleTextView.trailingAnchor.constraint(equalTo: titleSection.trailingAnchor, constant: -20),
            titleTextView.bottomAnchor.constraint(equalTo: titleSection.bottomAnchor),
            titleTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 54)
        ])

        // Button wrapper with padding
        let buttonStack = UIStackView(arrangedSubviews: [saveButton, deleteButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        let buttonWrapper = UIView()
        buttonWrapper.translatesAutoresizingMaskIntoConstraints = false
        buttonWrapper.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: buttonWrapper.topAnchor),
            buttonStack.leadingAnchor.constraint(equalTo: buttonWrapper.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: buttonWrapper.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: buttonWrapper.bottomAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            deleteButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        contentStack.addArrangedSubview(imageContainer)
        contentStack.addArrangedSubview(titleSection)
        contentStack.addArrangedSubview(buttonWrapper)
        contentStack.setCustomSpacing(28, after: imageContainer)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - Image Loading
    private func loadImage() {
        let urlString = photo.url
        if let cached = sharedImageCache.object(forKey: urlString as NSString) {
            fullImageView.image = cached
            detailPlaceholderView.isHidden = true
            return
        }
        guard let url = URL(string: urlString) else {
            detailPlaceholderView.isHidden = false
            return
        }
        
        activityIndicator.startAnimating()
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                guard error == nil, let data, let image = UIImage(data: data) else {
                    self.detailPlaceholderView.isHidden = false
                    return
                }
                self.detailPlaceholderView.isHidden = true
                sharedImageCache.setObject(image, forKey: urlString as NSString, cost: data.count)
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

        // Brief button feedback (optimistic)
        saveButton.configuration?.title = "Saved ✓"
        saveButton.configuration?.image = UIImage(systemName: "checkmark.circle.fill")
        saveButton.configuration?.baseBackgroundColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.saveButton.configuration?.title = "Save Title"
            self?.saveButton.configuration?.image = UIImage(systemName: "checkmark")
            self?.saveButton.configuration?.baseBackgroundColor = .systemBlue
        }
    }

    /// Called externally when Core Data fails to persist the title change.
    func showSaveError(_ message: String) {
        // Revert button to its normal state immediately
        saveButton.configuration?.title = "Save Title"
        saveButton.configuration?.image = UIImage(systemName: "checkmark")
        saveButton.configuration?.baseBackgroundColor = .systemBlue

        let alert = UIAlertController(
            title: "Save Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        if presentedViewController == nil {
            present(alert, animated: true)
        }
    }


    @objc private func deleteTapped() {
        let title = photo.title.isEmpty ? "Photo #\(photo.id)" : photo.title
        let alert = UIAlertController(
            title: "Delete Photo",
            message: "Are you sure you want to delete \"\(title)\"?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDelete()
        })
        present(alert, animated: true)
    }

    private func performDelete() {
        // Disable buttons while deleting
        deleteButton.isEnabled = false
        navigationItem.rightBarButtonItem?.isEnabled = false

        onPhotoDeleted?(photoIndex)
        navigationController?.popViewController(animated: true)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: frame.height, right: 0)
        scrollView.contentInset = insets
        scrollView.scrollIndicatorInsets = insets
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
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
