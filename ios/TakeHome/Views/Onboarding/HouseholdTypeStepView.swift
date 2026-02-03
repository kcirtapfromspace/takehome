import SwiftUI

struct HouseholdTypeStepView: View {
    @Binding var householdType: HouseholdType

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Who's in your household?")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This helps us calculate proportional expense splitting")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                ForEach(HouseholdType.allCases) { type in
                    HouseholdTypeCard(
                        type: type,
                        isSelected: householdType == type,
                        onSelect: {
                            if type.isAvailable {
                                householdType = type
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct HouseholdTypeCard: View {
    let type: HouseholdType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(type.displayName)
                            .font(.headline)
                            .foregroundColor(type.isAvailable ? .primary : .secondary)

                        if !type.isAvailable {
                            Text("Coming Soon")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray)
                                .cornerRadius(4)
                        }
                    }

                    Text(type.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? .accentColor.opacity(0.3) : .black.opacity(0.05), radius: isSelected ? 8 : 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!type.isAvailable)
        .opacity(type.isAvailable ? 1 : 0.6)
    }
}

#Preview {
    HouseholdTypeStepView(householdType: .constant(.single))
}
