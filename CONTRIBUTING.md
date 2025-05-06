# Contributing to Terraform Proxmox Kubernetes 🚀

Hey there! Thanks for checking out the **Terraform Proxmox Kubernetes** project. We’re stoked that you’re interested in contributing! Whether you’ve got a bug fix, a cool feature idea, or just wanna help improve the docs, we’d love your input. Here’s how you can jump in. 😎

## 🐛 Reporting Bugs or Suggesting Features
Got a bug to report or an idea for a new feature? Awesome! Open an [issue](https://github.com/chrodrigues/terraform-proxmox-k8s/issues) and let us know. Here’s what to include:
- **For Bugs**:
  - What’s the issue? Describe what’s going wrong.
  - Steps to reproduce it (ex.: “I ran `terraform apply` and got this error…”).
  - Expected behavior (ex.: “I expected the cluster to come up, but…”).
  - Logs or screenshots (ex.: output from `/tmp/cloud-init.log` or Terraform errors).
- **For Features**:
  - What’s your idea? Be as detailed as you can.
  - Why would it be useful? (ex.: “Adding support for Helm would let us…”).

## 🛠️ Submitting a Pull Request (PR)
Wanna contribute code, docs, or fixes? Here’s how to submit a PR:
1. **Fork and Clone**: Fork the repo and clone it locally.
   ```bash
   git clone https://github.com/your-username/terraform-proxmox-k8s.git
   cd terraform-proxmox-k8s
   ```
2. **Create a Branch**: Make a new branch for your changes.
   ```bash
   git checkout -b feature/your-cool-feature
   ```
   Use a descriptive name (ex.: `bug/fix-dns-config`, `docs/update-readme`).
3. **Set Up Your Environment**:
   - Make sure you have Terraform 1.3+ installed.
   - You’ll need Proxmox VE 7.0+ to test changes (check the [README](README.md) for prereqs).
   - Copy your `secret.auto.tfvars` with Proxmox creds (see [README](README.md#2-set-up-your-variables)).
4. **Make Your Changes**:
   - For Terraform code, run `terraform fmt` to format files (we like clean code!).
   - Test your changes locally with `terraform apply` in a Proxmox environment.
   - If adding features, update the [README](README.md) with any new instructions.
5. **Commit and Push**:
   - Write clear commit messages (ex.: “Add support for custom DNS servers”).
   ```bash
   git add .
   git commit -m "Your commit message"
   git push origin feature/your-cool-feature
   ```
6. **Open a PR**:
   - Go to the repo on GitHub and open a pull request from your branch.
   - Describe your changes in the PR description (what you did, why, and how you tested it).
   - Link to any related issues (ex.: “Fixes #42”).

We’ll review your PR as soon as we can! If there’s feedback, we’ll let you know what to tweak.

## 📝 Code Style
- **Terraform**: Run `terraform fmt` on all `.tf` files to keep things tidy.
- **Docs**: Keep the tone friendly and clear, like the [README](README.md).
- **Tests**: If you add a feature, test it in a Proxmox environment and share the results in your PR.

## 📬 Need Help?
Got questions? Feel free to open an [issue](https://github.com/chrodrigues/terraform-proxmox-k8s/issues) with your question, or ping me on [X](https://x.com/your-handle). Let’s build something awesome together! 💪