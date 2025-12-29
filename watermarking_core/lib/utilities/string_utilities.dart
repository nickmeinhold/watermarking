String? trimToLast(int trimmedLength, String? trimString) {
  if (trimString == null || trimString.length <= trimmedLength) {
    return trimString;
  }
  return '...${trimString.substring(trimString.length - trimmedLength)}';
}
