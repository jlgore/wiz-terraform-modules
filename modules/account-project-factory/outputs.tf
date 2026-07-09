output "projects" {
  description = "Created projects keyed by account slug."
  value = {
    for key, p in wiz-v2_project.this :
    key => {
      id                 = p.id
      name               = p.name
      security_champions = p.security_champions
      project_owners     = p.project_owners
    }
  }
}

output "project_ids" {
  description = "Map of account slug => created project ID (handy for wiring automation rules)."
  value       = { for key, p in wiz-v2_project.this : key => p.id }
}

output "resolved_owners" {
  description = "Map of account slug => owner emails actually applied."
  value       = local.owners
}

output "accounts_without_owners" {
  description = "Account slugs that resolved to zero owners — surface these; they got no champions."
  value       = [for key, owners in local.owners : key if length(owners) == 0]
}
