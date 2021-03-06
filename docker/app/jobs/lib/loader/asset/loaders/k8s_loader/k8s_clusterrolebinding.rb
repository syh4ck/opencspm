class K8S_CLUSTERROLEBINDING < K8sLoader

  def initialize(asset, db, import_id)
    super
  end

  def load

    role_ref = {}
    if asset.dig('resource','data','roleRef')
      role_ref = asset.dig('resource', 'data').delete('roleRef')
    end
    role_type = role_ref['kind']

    full_role_name = "Unknown"
    if matches = @asset_name.match(%r{(?<base>.*\/)clusterrolebindings\/.*})
      full_role_name = "#{matches[:base]}clusterroles/#{role_ref['name']}"
    end
    
    subjects = []
    if asset.dig('resource','data','subjects')
      subjects = asset.dig('resource', 'data').delete('subjects')
    end

    k8s_resource_upsert(@asset, @asset_type, @asset_label, @asset_name)

    # CLUSTERROLEBINDING -> HAS_RBAC_ROLE -> RBAC_CLUSTERROLE
    supporting_relationship("K8S_CLUSTERROLEBINDING", @asset_name, "K8S_CLUSTERROLE", full_role_name, "k8s.io/ClusterRole", "k8s", "HAS_RBAC_ROLE", "left")

    unless subjects.nil?
      subjects.each do |subject|
        if subject.dig('namespace') && subject.dig('kind') == 'ServiceAccount'
          # SA 
          if matches = @asset_name.match(%r{(?<base>.*\/v1\/).*})
            sa_name = "#{matches[:base]}#{subject.dig('namespace')}/serviceaccounts/#{subject.dig('name')}"
            supporting_relationship_with_attrs("K8S_CLUSTERROLEBINDING", @asset_name, "K8S_SERVICEACCOUNT", sa_name, "k8s.io/ServiceAccount", {}, "k8s", "HAS_RBAC_SUBJECT", {}, "left")
          end
        else
          apiGroup = subject.dig('apiGroup')
          kind = subject.dig('kind')
          name = subject.dig('name')
          if name && kind && apiGroup
            # Users or Groups
            full_name = "#{apiGroup}/#{kind}__#{name}"
            subj_attrs = { "apiGroup" => apiGroup, "kind" => kind, "name" => name }
            supporting_relationship_with_attrs("K8S_CLUSTERROLEBINDING", @asset_name, "K8S_RBAC_SUBJECT", full_name, "k8s.io/RbacSubject", subj_attrs, "k8s", "HAS_RBAC_SUBJECT", {}, "left")
          end
        end
      end
    end
  end
end
