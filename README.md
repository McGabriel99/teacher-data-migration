# Teacher Data Migration Script (PowerShell)

A real-world PowerShell script used to automate and streamline user data transfers during teacher computer replacements.

## ✨ Features
- Copies files from a user profile on a remote PC
- Prioritizes folders first, regardless of last modified date
- Applies conditional logic for root-level files based on folder size
- Fully logs copied items and skipped folders
- Supports manual targeting via `-teacher` and `-oldPC` parameters

## 📁 Folder Logic
| Folder Size | Files Copied |
|-------------|--------------|
| ≥ 4GB       | Files modified within last 2 years |
| < 4GB       | All files |

> All folders and their contents are always copied regardless of age.

## 🧪 Usage
```powershell
.\Transfer-Files-Final.ps1 -teacher jdoe -oldPC teacher-laptop01
