import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import colors from '../theme/colors';

const SASSY_COMMENTS = [
  'War nix.',
  'Zu langsam.',
  'Glück gehabt.',
  'Versuch\'s nochmal.',
  'Pathetic.',
  'Das war peinlich.',
  'Ich schlafe fast.',
  'Mein Großvater wäre schneller.',
  'Bitte üben.',
  'LOL.',
];

export default function MasterMo({ comment, onPoke, size = 'medium' }) {
  const [currentComment, setCurrentComment] = useState(
    comment || SASSY_COMMENTS[Math.floor(Math.random() * SASSY_COMMENTS.length)]
  );

  const handlePoke = () => {
    const newComment = SASSY_COMMENTS[Math.floor(Math.random() * SASSY_COMMENTS.length)];
    setCurrentComment(newComment);
    if (onPoke) onPoke(newComment);
  };

  const avatarSize = size === 'large' ? 90 : size === 'small' ? 50 : 70;
  const emojiSize = size === 'large' ? 48 : size === 'small' ? 26 : 36;

  return (
    <View style={styles.container}>
      <View style={styles.speechBubble}>
        <Text style={styles.speechText}>{currentComment}</Text>
        <View style={styles.bubbleTail} />
      </View>
      <TouchableOpacity
        onPress={handlePoke}
        activeOpacity={0.8}
        style={[styles.avatar, { width: avatarSize, height: avatarSize, borderRadius: avatarSize / 2 }]}
      >
        <Text style={{ fontSize: emojiSize }}>🤖</Text>
      </TouchableOpacity>
      <Text style={styles.name}>Master Mo</Text>
    </View>
  );
}

export { SASSY_COMMENTS };

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
  },
  speechBubble: {
    backgroundColor: colors.surfaceElevated,
    borderRadius: 14,
    paddingHorizontal: 16,
    paddingVertical: 10,
    marginBottom: 8,
    maxWidth: 220,
    borderWidth: 1,
    borderColor: colors.border,
    position: 'relative',
  },
  speechText: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '600',
    textAlign: 'center',
    fontStyle: 'italic',
  },
  bubbleTail: {
    position: 'absolute',
    bottom: -8,
    left: '50%',
    marginLeft: -8,
    width: 0,
    height: 0,
    borderLeftWidth: 8,
    borderRightWidth: 8,
    borderTopWidth: 8,
    borderLeftColor: 'transparent',
    borderRightColor: 'transparent',
    borderTopColor: colors.surfaceElevated,
  },
  avatar: {
    backgroundColor: colors.surface,
    borderWidth: 2,
    borderColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  name: {
    color: colors.accent,
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 1,
    marginTop: 6,
    textTransform: 'uppercase',
  },
});
