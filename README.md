# FINN Invoice Tracking - Setup Guide

## Prerequisites
- Node.js (v18 or higher)
- SAP UI5 CLI
- Access to SAP backend system

## Initial Setup

### 1. Clone the Repository
```bash
git clone https://github.com/swarajrath/Finn_Invoice_Generator.git
cd FINN_CaseStudy
```

### 2. Install Fiori App Dependencies
```bash
cd finninvoicetracking
npm install
```

### 3. Configure Backend Connection

Copy the template file and configure your system:
```bash
cp ui5.yaml.template ui5.yaml
```

Edit `ui5.yaml` and replace placeholders:
- `YOUR_SAP_SYSTEM_URL_HERE` → Your SAP system URL (e.g., `https://ldai4er1.wdf.sap.corp:44300`)
- `YOUR_DESTINATION_NAME` → Your SAP destination name (e.g., `ER1CLNT001`)

**⚠️ IMPORTANT:** Never commit `ui5.yaml` to Git as it contains your system URLs!

### 4. Run the Application
```bash
npm start
```

The app will open at `http://localhost:8080`

## Project Structure

```
FINN_CaseStudy/
├── 01_Database_Design/      # Database table DDL definitions
├── ABAP_Classes/             # ABAP behavior implementations and utilities
├── CDS_Views/                # CDS views and behavior definitions
├── finninvoicetracking/      # Fiori Elements UI5 application
│   ├── webapp/
│   │   ├── manifest.json     # App descriptor
│   │   ├── annotations.xml   # OData annotations
│   │   └── ext/              # Controller extensions
│   ├── ui5.yaml.template     # Template for backend configuration
│   └── package.json
└── .gitignore
```

## Deployment

### To SAP BTP (Cloud Foundry)
```bash
npm run build
cf push
```

### To SAP ABAP Repository
Use SAP Business Application Studio or VS Code with SAP Fiori tools extension.

## Security Notes

Files excluded from Git (`.gitignore`):
- `ui5.yaml` - Contains backend system URLs
- `ui5-local.yaml` - Local development configuration
- `.env` - Environment variables
- `node_modules/` - Dependencies
- `API_Design/` - API design documents
- `Back_UP_Files/` - Backup files

## Support

For issues or questions, please create an issue in the GitHub repository.

## License

[Add your license here]
